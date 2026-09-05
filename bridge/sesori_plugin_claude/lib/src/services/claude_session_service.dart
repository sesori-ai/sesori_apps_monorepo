import "dart:async";
import "dart:collection";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/claude_stream_message.dart";
import "../claude_approval_registry.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";
import "../models/claude_task_status.dart";
import "../models/claude_task_type.dart";
import "../models/claude_tool_use_result.dart";
import "../repositories/claude_session_process_repository.dart";

/// A queued prompt that the service wrote to Claude's stdin.
final class const ClaudeTurnDispatched({
  required final String sessionId,

  /// The normalized directory the turn was dispatched in, so consumers need
  /// not resolve it again.
  required final String directory,
  required final String promptId,
  required final String? displayText,
  required final String? command,
  required final bool isSteering,
});

/// One prompt accepted for a session but not yet visible as a transcript
/// message. Stays queued (and cancellable until dispatch) from acceptance
/// until its user message is emitted.
final class _QueuedPrompt({
  required final String id,
  required final String? displayText,
  required final String? command,
  required final int attachmentCount,
  required final int createdAt,
}) {
  bool dispatched = false;
}

final class _SessionTurnState() {
  Future<void> dispatchTail = Future<void>.value();
  final Set<Future<void>> settlements = {};
  int pending = 0;
  int generation = 0;
  int idleGeneration = 0;

  /// Non-null while abort interrupts and tears down the resident process.
  /// Sends accepted during that window wait here before establishing fresh
  /// residency.
  Completer<void>? aborting;

  /// True while the CLI runs a turn the bridge did not enqueue.
  ///
  /// A `ScheduleWakeup` loop wakeup starts a turn inside the resident process
  /// with no `enqueueTurn` call: frames stream while [pending] is zero. The
  /// completer keeps that turn visible (busy status, work state, abort) and
  /// gives boundary-requiring sends a future to await until its `result` lands.
  Completer<void>? selfStartedTurn;

  /// When the CLI's pending `ScheduleWakeup` timer fires, or null when none
  /// is scheduled.
  ///
  /// The timer lives only inside the resident process — killing the process
  /// kills the wakeup, and `--resume` does not rearm it (verified against CLI
  /// 2.1.233) — so the idle reap must not tear the process down before the
  /// wakeup fires.
  DateTime? wakeupAt;

  /// Background tasks (sub-agents, shells, workflows) the resident process is
  /// running, by task id. They live only inside that process, so while any is
  /// present the session is busy and the idle reap must not tear it down. The
  /// type is kept for the scoped-stop rejection count.
  final Map<String, ClaudeTaskType> runningTaskIds = {};

  /// Whether the CLI is doing anything the bridge must keep the process for.
  bool get hasWork => pending > 0 || selfStartedTurn != null || runningTaskIds.isNotEmpty;

  final List<_QueuedPrompt> queue = [];

  /// Prompt ids dispatched most recently, newest last. Bounds the idempotent
  /// retry window: a client that lost the acceptance response can re-send the
  /// same prompt id and be refused as an already-done no-op.
  final Queue<String> recentlyDispatched = Queue<String>();
}

/// Serializes Claude dispatch and selection changes while allowing ordinary
/// prompts to steer active turns. Also owns work/idle lifecycle policy and the
/// bridge-owned queued-prompt state.
final class ClaudeSessionService({
  required final ClaudeSessionProcessRepository _processes,
  required final ClaudeApprovalRegistry _approvals,
  required final ServerClock _clock,

  /// Resolves the current per-session idle timeout, or null when idle reaping
  /// is disabled. Read whenever an idle timer is armed.
  required final Duration? Function() _resolveIdleTimeout,
  required final Stream<Duration?> _idleTimeoutChanges,
}) {
  this {
    _processes.events.listen(_handleProcessEvent).addTo(_subscriptions);
    _idleTimeoutChanges.listen(_handleIdleTimeoutChange).addTo(_subscriptions);
  }

  /// See [_SessionTurnState.recentlyDispatched]. 64 comfortably exceeds any
  /// realistic gap between a lost acceptance response and its retry (the
  /// retry fires on the next reconnect/refresh drain).
  static const int _recentlyDispatchedLimit = 64;

  final Map<String, _SessionTurnState> _turns = {};
  final Map<String, PluginSessionStatus> _retryStatuses = {};
  final StreamController<BridgeSseEvent> _events = StreamController.broadcast();
  final StreamController<ClaudeTurnDispatched> _dispatches = StreamController.broadcast(sync: true);
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.idle);
  final PendingOperations _inFlightTeardowns = PendingOperations();
  final Map<String, Future<void>> _teardownsBySession = {};
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => _events.stream;
  Stream<ClaudeTurnDispatched> get dispatches => _dispatches.stream;
  Stream<PluginWorkState> get workState => _workState.stream;
  PluginWorkState get currentWorkState => _workState.current;

  Map<String, PluginSessionStatus> get sessionStatuses => Map.unmodifiable({
    for (final entry in _turns.entries)
      entry.key:
          _retryStatuses[entry.key] ??
          (entry.value.hasWork ? const PluginSessionStatus.busy() : const PluginSessionStatus.idle()),
  });

  /// Whether the main agent itself is mid-turn — a queued or self-started turn —
  /// as opposed to the session being busy only because background tasks run.
  bool isTurnRunning({required String sessionId}) => switch (_turns[sessionId]) {
    final state? => state.pending > 0 || state.selfStartedTurn != null,
    null => false,
  };

  /// The session's accepted-but-not-yet-visible prompts, in dispatch order.
  List<PluginQueuedPrompt> queuedPrompts({required String sessionId}) {
    final state = _turns[sessionId];
    if (state == null) return const [];
    return [
      for (final entry in state.queue)
        PluginQueuedPrompt(
          id: entry.id,
          text: entry.displayText,
          command: entry.command,
          attachmentCount: entry.attachmentCount,
          createdAt: entry.createdAt,
        ),
    ];
  }

  /// Cancels the not-yet-dispatched queued prompt [promptId].
  ///
  /// Returns whether an entry was removed. A dispatched entry refuses: from
  /// that moment the prompt is a turn, governed by [abort].
  bool cancelQueuedPrompt({required String sessionId, required String promptId}) {
    final state = _turns[sessionId];
    if (state == null) return false;
    final index = state.queue.indexWhere((entry) => entry.id == promptId && !entry.dispatched);
    if (index == -1) return false;
    state.queue.removeAt(index);
    _emitQueueUpdate(sessionId: sessionId, state: state);
    return true;
  }

  /// Removes [promptId]'s queued entry once its user message became visible.
  ///
  /// Emits the queue update on the service stream, whose async delivery lands
  /// after the caller's directly-buffered message events — clients therefore
  /// always see the message before the entry disappears and can transform the
  /// queued bubble in place. Returns false when abort or another lifecycle
  /// transition already removed the entry.
  bool consumeQueuedPrompt({required String sessionId, required String promptId}) {
    final state = _turns[sessionId];
    if (state == null) return false;
    final index = state.queue.indexWhere((entry) => entry.id == promptId);
    if (index == -1) return false;
    state.queue.removeAt(index);
    _emitQueueUpdate(sessionId: sessionId, state: state);
    return true;
  }

  /// Queues a prompt or command turn and accepts it immediately.
  ///
  /// The returned future completes at enqueue — never after the turns ahead
  /// of it — so callers holding a client request open respond instantly. A
  /// [promptId] already queued or recently dispatched is an idempotent
  /// success no-op (the retry of a send whose response was lost).
  ///
  /// Ordinary prompts are written with Claude's steering priority as soon as
  /// the resident process is ready. Commands and selection changes retain a
  /// turn boundary. A typed [dispatches] event follows each write so the plugin
  /// can publish the corresponding user message. Dispatch failures surface as
  /// a session error and remove the entry — acceptance is not revoked.
  Future<void> enqueueTurn({
    required String sessionId,
    required String directory,
    required bool createNew,
    required List<PluginPromptPart> parts,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required String promptId,
    required String? displayText,
    required String? command,
    required int attachmentCount,
  }) {
    if (_disposed || parts.isEmpty) {
      return Future.error(StateError("Claude session cannot accept the turn"));
    }
    final state = _turns.putIfAbsent(sessionId, _SessionTurnState.new);
    final isDuplicate = state.queue.any((entry) => entry.id == promptId) || state.recentlyDispatched.contains(promptId);
    if (isDuplicate) return Future.value();

    final entry = _QueuedPrompt(
      id: promptId,
      displayText: displayText,
      command: command,
      attachmentCount: attachmentCount,
      createdAt: _clock.now().millisecondsSinceEpoch,
    );
    state.queue.add(entry);
    _beginTurnAccounting(sessionId: sessionId, state: state);
    _emitQueueUpdate(sessionId: sessionId, state: state);
    final generation = state.generation;
    state.dispatchTail = state.dispatchTail.then(
      (_) => _dispatchTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: createNew,
        parts: parts,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        state: state,
        generation: generation,
        mode: _QueuedTurnMode(entry: entry),
      ),
    );
    return Future.value();
  }

  /// Queues a session's very first turn and completes only when the backend
  /// accepted it, so session creation can roll back a session whose initial
  /// prompt never started. Never used for sends to existing sessions.
  Future<void> enqueueInitialTurn({
    required String sessionId,
    required String directory,
    required bool createNew,
    required List<PluginPromptPart> parts,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
  }) {
    if (_disposed || parts.isEmpty) {
      return Future.error(StateError("Claude session cannot accept the turn"));
    }
    final acceptance = Completer<void>();
    final state = _turns.putIfAbsent(sessionId, _SessionTurnState.new);
    _beginTurnAccounting(sessionId: sessionId, state: state);
    final generation = state.generation;
    state.dispatchTail = state.dispatchTail.then(
      (_) => _dispatchTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: createNew,
        parts: parts,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        state: state,
        generation: generation,
        mode: _BlockingTurnMode(acceptance: acceptance),
      ),
    );
    return acceptance.future;
  }

  void _beginTurnAccounting({required String sessionId, required _SessionTurnState state}) {
    _retryStatuses.remove(sessionId);
    state.pending++;
    state.idleGeneration++;
    if (state.pending == 1) {
      _workState.set(PluginWorkState.busy);
      _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.busy()));
      _emit(const BridgeSseProjectUpdated());
    }
  }

  Future<void> _dispatchTurn({
    required String sessionId,
    required String directory,
    required bool createNew,
    required List<PluginPromptPart> parts,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required _SessionTurnState state,
    required int generation,
    required _TurnMode mode,
  }) async {
    if (!_isCurrent(sessionId: sessionId, state: state, generation: generation) || _isCancelled(mode, state)) {
      mode.settleUnaccepted();
      return _finish(sessionId, state, null);
    }
    try {
      final aborting = state.aborting?.future;
      if (aborting != null) await aborting;
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation) || _isCancelled(mode, state)) {
        mode.settleUnaccepted();
        return _finish(sessionId, state, null);
      }
      if (_requiresTurnBoundary(
        sessionId: sessionId,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        mode: mode,
      )) {
        final selfStartedTurn = state.selfStartedTurn?.future;
        await Future.wait([
          ...state.settlements,
          ?selfStartedTurn,
        ]);
      }
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation) || _isCancelled(mode, state)) {
        mode.settleUnaccepted();
        return _finish(sessionId, state, null);
      }
      await _processes.ensureResident(
        sessionId: sessionId,
        directory: directory,
        createNew: createNew,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        allowedTools: _approvals.allowedToolsForSession(sessionId: sessionId),
      );
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation) || _isCancelled(mode, state)) {
        mode.settleUnaccepted();
        return _finish(sessionId, state, null);
      }
      final dispatch = _processes.sendTurn(
        sessionId: sessionId,
        parts: parts,
        promptId: mode.replayPromptId,
      );
      if (!dispatch.accepted) {
        throw StateError("Claude rejected the turn before dispatch");
      }
      final isSteering = state.selfStartedTurn != null || state.settlements.isNotEmpty;
      switch (mode) {
        case _BlockingTurnMode(:final acceptance):
          if (!acceptance.isCompleted) acceptance.complete();
        case _QueuedTurnMode(:final entry):
          entry.dispatched = true;
          _recordDispatched(state: state, promptId: entry.id);
          if (!_dispatches.isClosed) {
            _dispatches.add(
              ClaudeTurnDispatched(
                sessionId: sessionId,
                directory: directory,
                promptId: entry.id,
                displayText: entry.displayText,
                command: entry.command,
                isSteering: isSteering,
              ),
            );
          }
      }
      late final Future<void> settlement;
      settlement = _settleDispatchedTurn(
        sessionId: sessionId,
        state: state,
        generation: generation,
        mode: mode,
        outcome: dispatch.outcome,
      ).whenComplete(() => state.settlements.remove(settlement));
      state.settlements.add(settlement);
      unawaited(settlement);
    } on Object catch (error, stack) {
      _failTurn(
        sessionId: sessionId,
        state: state,
        generation: generation,
        mode: mode,
        error: error,
        stack: stack,
      );
    }
  }

  bool _requiresTurnBoundary({
    required String sessionId,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required _TurnMode mode,
  }) {
    if (mode is _QueuedTurnMode && mode.entry.command != null) return true;
    final applied = _processes.appliedSelection(sessionId: sessionId);
    return applied != null &&
        (applied.model != model || applied.effort != effort || applied.permissionMode != permissionMode);
  }

  Future<void> _settleDispatchedTurn({
    required String sessionId,
    required _SessionTurnState state,
    required int generation,
    required _TurnMode mode,
    required Future<ClaudeTurnOutcome> outcome,
  }) async {
    try {
      final settled = await outcome;
      _settleQueuedEntry(sessionId: sessionId, state: state, mode: mode);
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        return _finish(sessionId, state, null);
      }
      _finish(sessionId, state, settled);
    } on Object catch (error, stack) {
      _failTurn(
        sessionId: sessionId,
        state: state,
        generation: generation,
        mode: mode,
        error: error,
        stack: stack,
      );
    }
  }

  void _failTurn({
    required String sessionId,
    required _SessionTurnState state,
    required int generation,
    required _TurnMode mode,
    required Object error,
    required StackTrace stack,
  }) {
    mode.settleError(error, stack);
    _settleQueuedEntry(sessionId: sessionId, state: state, mode: mode);
    if (_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
      Log.w("[claude] queued turn failed for $sessionId", error, stack);
      _finish(sessionId, state, const ClaudeTurnFailed());
    } else {
      _finish(sessionId, state, null);
    }
  }

  /// A cancelled queued entry was already removed from the queue; its chained
  /// link must settle without dispatching.
  bool _isCancelled(_TurnMode mode, _SessionTurnState state) =>
      mode is _QueuedTurnMode && !state.queue.contains(mode.entry) && !mode.entry.dispatched;

  void _recordDispatched({required _SessionTurnState state, required String promptId}) {
    state.recentlyDispatched.addLast(promptId);
    while (state.recentlyDispatched.length > _recentlyDispatchedLimit) {
      state.recentlyDispatched.removeFirst();
    }
  }

  /// Removes a queued entry that never became a visible message (interrupt or
  /// failure between dispatch and echo, or a dispatch that threw).
  void _settleQueuedEntry({required String sessionId, required _SessionTurnState state, required _TurnMode mode}) {
    if (mode is! _QueuedTurnMode) return;
    // A deleted/reset session already dropped this state; a stale turn must
    // not publish queue updates after BridgeSseSessionDeleted.
    if (!identical(_turns[sessionId], state)) return;
    if (!state.queue.contains(mode.entry)) return;
    state.queue.remove(mode.entry);
    _emitQueueUpdate(sessionId: sessionId, state: state);
  }

  /// Stops the session's work with the given sub-agent scope.
  ///
  /// `confirm` is refused while typed sub-agents run, with no side effect, so
  /// the caller can ask the user. `keep` leaves the process resident so its
  /// tasks continue and their notifications wake the main agent as usual — but
  /// only while no main turn runs, because the CLI's interrupt would stop the
  /// sub-agents too; `stop`, and `keep` during a live main turn or with
  /// nothing resident, interrupts and tears the process down, cancelling every
  /// task with it.
  Future<PluginAbortResult> abort({required String sessionId, required PluginAbortSubAgentPolicy subAgents}) async {
    final state = _turns[sessionId];
    if (state == null) return const PluginAbortAccepted(workKept: false);
    final activeAbort = state.aborting;
    if (activeAbort != null) {
      // The in-flight abort may have kept work this caller wants stopped; run
      // the requested scope once its fence releases.
      await activeAbort.future;
      return await abort(sessionId: sessionId, subAgents: subAgents);
    }
    final runningSubAgents = state.runningTaskIds.values.where((type) => type == ClaudeTaskType.subAgent).length;
    if (subAgents == PluginAbortSubAgentPolicy.confirm && runningSubAgents > 0) {
      return PluginAbortRejectedSubAgentsRunning(
        runningSubAgentCount: runningSubAgents,
        mainAgentRunning: state.pending > 0 || state.selfStartedTurn != null,
        mainAgentOnlySupported: false,
      );
    }
    if (!state.hasWork) {
      _approvals.cancelForSession(sessionId: sessionId);
      return const PluginAbortAccepted(workKept: false);
    }
    // The CLI's only stop primitive, `interrupt`, also stops background agents
    // (observed on 2.1.257), so sub-agents can be kept only when no main turn
    // needs interrupting; a `keep` during a live main turn is refused so the
    // caller learns the scope cannot be honored instead of losing the work.
    final keepTasks = subAgents == PluginAbortSubAgentPolicy.keep && runningSubAgents > 0;
    if (keepTasks && (state.pending > 0 || state.selfStartedTurn != null)) {
      return PluginAbortRejectedSubAgentsRunning(
        runningSubAgentCount: runningSubAgents,
        mainAgentRunning: true,
        mainAgentOnlySupported: false,
      );
    }
    final aborting = Completer<void>();
    state.aborting = aborting;
    try {
      state.generation++;
      state.idleGeneration++;
      if (state.queue.isNotEmpty) {
        state.queue.clear();
        _emitQueueUpdate(sessionId: sessionId, state: state);
      }
      if (keepTasks) {
        // Nothing to interrupt: the main agent is idle and only background tasks
        // run. The process stays resident for them, pending approvals are left
        // alone (a kept sub-agent may be waiting on one), and the running set
        // keeps the session busy until the tasks report and wake the main agent.
        return const PluginAbortAccepted(workKept: true);
      }
      _approvals.cancelForSession(sessionId: sessionId);
      // Teardown kills the CLI's in-process wakeup timer, and `--resume` does
      // not rearm it, so a pending wakeup cannot survive an abort.
      state.wakeupAt = null;
      try {
        await _processes.interrupt(sessionId: sessionId);
      } on Object catch (error, stack) {
        Log.w("[claude] interrupt failed for $sessionId", error, stack);
      } finally {
        // Claude can emit recovery/meta turns after an acknowledged interrupt.
        // Resume from the persisted transcript in a fresh process instead of
        // allowing that transport backlog to enter the next user turn.
        await _processes.teardown(sessionId: sessionId);
      }
      // Every resident task died with the process.
      state.runningTaskIds.clear();
      if (identical(_turns[sessionId], state)) {
        _completeSelfStartedTurn(state: state);
        _settleIdle(sessionId: sessionId, state: state);
      }
      return const PluginAbortAccepted(workKept: false);
    } finally {
      if (identical(state.aborting, aborting)) state.aborting = null;
      if (!aborting.isCompleted) aborting.complete();
    }
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        for (final entry in _turns.entries)
          if (entry.value.hasWork) entry.key,
      };
      if (activeSessionIds.isEmpty) return const <String>{};
      await Future.wait([
        for (final sessionId in activeSessionIds)
          abort(sessionId: sessionId, subAgents: PluginAbortSubAgentPolicy.stop),
      ]);
      if (currentWorkState != PluginWorkState.idle) {
        await workState.firstWhere((state) => state == PluginWorkState.idle);
      }
      return Set<String>.unmodifiable(activeSessionIds);
    }().timeout(budget);
  }

  Future<void> deleteSession({required String sessionId}) async {
    final state = _turns.remove(sessionId);
    if (state != null) {
      state.generation++;
      state.idleGeneration++;
      _completeSelfStartedTurn(state: state);
    }
    _retryStatuses.remove(sessionId);
    _approvals.forgetSession(sessionId: sessionId);
    final existingTeardown = _teardownsBySession[sessionId];
    if (existingTeardown != null) await existingTeardown;
    await _processes.teardown(sessionId: sessionId);
    _processes.forgetSession(sessionId: sessionId);
    _syncWorkState();
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    for (final state in _turns.values) {
      state.generation++;
      state.idleGeneration++;
      _completeSelfStartedTurn(state: state);
    }
    await _subscriptions.cancel();
    _approvals.dispose();
    await _processes.dispose();
    await _inFlightTeardowns.drain();
    await _events.close();
    await _dispatches.close();
    await _workState.close();
  }

  bool _isCurrent({required String sessionId, required _SessionTurnState state, required int generation}) =>
      !_disposed && identical(_turns[sessionId], state) && state.generation == generation;

  void _finish(String sessionId, _SessionTurnState state, ClaudeTurnOutcome? outcome) {
    _retryStatuses.remove(sessionId);
    if (state.pending > 0) state.pending--;
    if (!identical(_turns[sessionId], state)) return;
    if (outcome is ClaudeTurnFailed) _emit(BridgeSseSessionError(sessionID: sessionId));
    _settleIdle(sessionId: sessionId, state: state);
  }

  /// Publishes idle and arms the reap once nothing keeps the process busy —
  /// no queued turn, no self-started turn, no running task.
  void _settleIdle({required String sessionId, required _SessionTurnState state}) {
    if (state.hasWork) return;
    _emit(BridgeSseSessionIdle(sessionID: sessionId));
    _emit(const BridgeSseProjectUpdated());
    _syncWorkState();
    _scheduleIdleReap(sessionId: sessionId, state: state);
  }

  void _handleIdleTimeoutChange(Duration? _) {
    if (_disposed) return;
    for (final entry in _turns.entries) {
      final state = entry.value;
      if (state.hasWork ||
          state.aborting != null ||
          !_processes.isResident(sessionId: entry.key) ||
          _teardownsBySession.containsKey(entry.key)) {
        continue;
      }
      _scheduleIdleReap(sessionId: entry.key, state: state);
    }
  }

  void _scheduleIdleReap({required String sessionId, required _SessionTurnState state}) {
    final generation = ++state.idleGeneration;
    final idleTimeout = _resolveIdleTimeout();
    if (idleTimeout == null) return;
    unawaited(() async {
      while (true) {
        await _clock.delay(duration: idleTimeout);
        if (_disposed || !identical(_turns[sessionId], state) || state.hasWork || state.idleGeneration != generation) {
          return;
        }
        final wakeupAt = state.wakeupAt;
        if (wakeupAt == null) break;
        // Teardown would silently kill the CLI's in-process wakeup timer, so
        // keep the process resident until the wakeup fires (the fired turn
        // rearms this reap). A wakeup that never fires — the loop ended
        // without a frame the bridge observed — stops deferring one idle
        // timeout past its fire time instead of pinning the process forever.
        if (_clock.now().isAfter(wakeupAt.add(idleTimeout))) break;
      }
      final teardown = _processes.teardown(sessionId: sessionId);
      unawaited(_inFlightTeardowns.track(operation: teardown));
      _teardownsBySession[sessionId] = teardown;
      try {
        await teardown;
      } finally {
        if (identical(_teardownsBySession[sessionId], teardown)) {
          unawaited(_teardownsBySession.remove(sessionId));
        }
        if (identical(_turns[sessionId], state) && state.pending == 0 && state.idleGeneration == generation) {
          _turns.remove(sessionId);
        }
      }
    }());
  }

  void _syncWorkState() =>
      _workState.set(_turns.values.any((state) => state.hasWork) ? PluginWorkState.busy : PluginWorkState.idle);

  void _emit(BridgeSseEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _emitQueueUpdate({required String sessionId, required _SessionTurnState state}) {
    _emit(
      BridgeSseQueuedPromptsUpdated(
        sessionID: sessionId,
        prompts: queuedPrompts(sessionId: sessionId),
      ),
    );
  }

  void recordRetryStatus({required String sessionId, required PluginSessionStatus status}) {
    if (_turns.containsKey(sessionId)) _retryStatuses[sessionId] = status;
  }

  void _handleProcessEvent(ClaudeSessionProcessEvent event) {
    switch (event) {
      case final ClaudeSessionProcessMessage event:
        // Transition before arming: a frame that both begins a self-started
        // turn and carries a new `ScheduleWakeup` must keep the new schedule.
        _trackSelfStartedTurn(sessionId: event.sessionId, message: event.message);
        _trackRunningTasks(sessionId: event.sessionId, message: event.message);
        _trackWakeupSchedule(sessionId: event.sessionId, message: event.message);
        _settleRetry(sessionId: event.sessionId, message: event.message);
        final request = event.controlRequest;
        if (request != null) _approvals.handle(sessionId: event.sessionId, message: request);
      case ClaudeSessionProcessExited():
        final state = _turns[event.sessionId];
        if (state != null) {
          // The wakeup timer and every resident task died with the process,
          // and `--resume` does not rearm or restart them.
          state.wakeupAt = null;
          final hadWork = state.selfStartedTurn != null || state.runningTaskIds.isNotEmpty;
          state.runningTaskIds.clear();
          _completeSelfStartedTurn(state: state);
          // Only work this exit ended may settle idle: the reap's own teardown
          // exits an already-idle session and must not rearm the reap.
          if (hadWork) _settleIdle(sessionId: event.sessionId, state: state);
        }
        _approvals.cancelForSession(sessionId: event.sessionId);
    }
  }

  /// Mirrors the resident process's running background tasks from its typed
  /// task frames. On a CLI without task frames the same ids arrive through the
  /// launching call's typed tool result and the `<task-notification>` text.
  void _trackRunningTasks({required String sessionId, required ClaudeStreamMessage message}) {
    final state = _turns[sessionId];
    if (state == null) return;
    switch (message) {
      case ClaudeTaskStartedMessage(taskId: final taskId?):
        state.runningTaskIds[taskId] = message.taskType;
      case ClaudeTaskNotificationMessage(taskId: final taskId?):
        state.runningTaskIds.remove(taskId);
        // A stopped task opens no wake-up turn; if it was the last work, the
        // session is idle now rather than at some later turn.
        _settleIdle(sessionId: sessionId, state: state);
      case ClaudeUserMessage(parentToolUseId: null):
        switch (message.toolUseResult) {
          case ClaudeToolUseResultAsyncLaunched(:final agentId):
            state.runningTaskIds.putIfAbsent(agentId, () => ClaudeTaskType.subAgent);
          case ClaudeToolUseResultCompleted(agentId: final agentId?):
            state.runningTaskIds.remove(agentId);
          case ClaudeToolUseResultCompleted() || ClaudeToolUseResultAbsent() || ClaudeToolUseResultUnknown():
            break;
        }
        for (final notification in message.taskNotifications) {
          state.runningTaskIds.remove(notification.taskId);
        }
        if (message.taskNotifications.isNotEmpty) _settleIdle(sessionId: sessionId, state: state);
      case ClaudeStreamMessage():
        break;
    }
  }

  /// Mirrors the CLI's pending `ScheduleWakeup` timer from the tool calls that
  /// arm and disarm it.
  ///
  /// The CLI clamps the requested delay, so [_SessionTurnState.wakeupAt] is a
  /// lower-bound estimate; the reap deferral adds the idle timeout as margin.
  void _trackWakeupSchedule({required String sessionId, required ClaudeStreamMessage message}) {
    if (message is! ClaudeAssistantMessage) return;
    final state = _turns[sessionId];
    if (state == null) return;
    final content = message.message["content"];
    if (content is! List) return;
    for (final block in content) {
      if (block is! Map || block["type"] != "tool_use" || block["name"] != "ScheduleWakeup") continue;
      final rawInput = block["input"];
      if (rawInput is! Map) continue;
      final input = rawInput.cast<String, Object?>();
      if (input["stop"] == true) {
        state.wakeupAt = null;
      } else if (input["delaySeconds"] case final num delaySeconds) {
        state.wakeupAt = _clock.now().add(Duration(seconds: delaySeconds.toInt()));
      }
    }
  }

  /// Surfaces a turn the CLI started on its own — a fired `ScheduleWakeup` —
  /// as busy/idle exactly like an enqueued turn.
  ///
  /// Only frames that prove turn activity begin one: token stream, assistant
  /// content, a permission ask, or a background task's completion (the CLI
  /// follows it with a wake-up turn, so busy spans launch → task → wake-up
  /// without a transient idle). Bookkeeping frames (`init`, `status`, unknown
  /// types) do not, so post-turn stragglers cannot re-busy a session, and
  /// forwarded sub-agent frames do not either: they are task activity, already
  /// held by [_SessionTurnState.runningTaskIds].
  void _trackSelfStartedTurn({required String sessionId, required ClaudeStreamMessage message}) {
    final state = _turns[sessionId];
    if (state == null) return;
    switch (message) {
      case ClaudeStreamEventMessage(parentToolUseId: final String _) ||
          ClaudeAssistantMessage(parentToolUseId: final String _):
        break;
      // A stopped task was killed (an interrupt, a stop_task); the CLI runs no
      // wake-up turn for it, so opening one here would pin the session busy. A
      // user frame carrying only stopped notifications (or none) is the same.
      case ClaudeTaskNotificationMessage(status: ClaudeTaskStatus.stopped):
        break;
      case ClaudeUserMessage()
          when message.taskNotifications.every((notification) => notification.status == ClaudeTaskStatus.stopped):
        break;
      case ClaudeStreamEventMessage() ||
          ClaudeAssistantMessage() ||
          ClaudeControlRequestMessage() ||
          ClaudeTaskNotificationMessage() ||
          ClaudeUserMessage():
        if (state.selfStartedTurn != null || state.pending > 0) return;
        state.selfStartedTurn = Completer<void>();
        // A live turn supersedes the pending-wakeup estimate that started it.
        state.wakeupAt = null;
        state.idleGeneration++;
        _workState.set(PluginWorkState.busy);
        _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.busy()));
        _emit(const BridgeSseProjectUpdated());
      case ClaudeResultMessage():
        if (state.selfStartedTurn != null) _endSelfStartedTurn(sessionId: sessionId, state: state);
      case ClaudeStreamMessage():
        break;
    }
  }

  /// Returns a retrying session to busy as soon as its retried request streams
  /// output again. Only a new turn or the turn's end clears the status
  /// otherwise, so a recovered retry would stay visible for the whole turn.
  void _settleRetry({required String sessionId, required ClaudeStreamMessage message}) {
    if (message is! ClaudeStreamEventMessage && message is! ClaudeAssistantMessage) return;
    if (_retryStatuses.remove(sessionId) == null) return;
    _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.busy()));
  }

  void _endSelfStartedTurn({required String sessionId, required _SessionTurnState state}) {
    _completeSelfStartedTurn(state: state);
    _settleIdle(sessionId: sessionId, state: state);
  }

  void _completeSelfStartedTurn({required _SessionTurnState state}) {
    final turn = state.selfStartedTurn;
    state.selfStartedTurn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }
}

/// How one chained turn reports acceptance and visibility.
sealed class const _TurnMode() {
  String? get replayPromptId;

  /// Settles a turn that was dropped before dispatch (stale generation or a
  /// cancelled queued entry).
  void settleUnaccepted();

  /// Settles a turn whose dispatch threw.
  void settleError(Object error, StackTrace stack);
}

/// A queued-entry turn accepted before dispatch.
final class const _QueuedTurnMode({required final _QueuedPrompt entry}) extends _TurnMode {
  @override
  String? get replayPromptId => entry.command == null ? entry.id : null;

  @override
  void settleUnaccepted() {}

  @override
  void settleError(Object error, StackTrace stack) {}
}

/// The blocking initial turn: acceptance completes only at dispatch.
final class const _BlockingTurnMode({required final Completer<void> acceptance}) extends _TurnMode {
  @override
  String? get replayPromptId => null;

  @override
  void settleUnaccepted() {
    if (!acceptance.isCompleted) {
      acceptance.completeError(StateError("Claude turn was cancelled before acceptance"));
    }
  }

  @override
  void settleError(Object error, StackTrace stack) {
    if (!acceptance.isCompleted) acceptance.completeError(error, stack);
  }
}
