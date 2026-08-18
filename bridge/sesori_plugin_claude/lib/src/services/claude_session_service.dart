import "dart:async";
import "dart:collection";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../claude_approval_registry.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";
import "../repositories/claude_session_process_repository.dart";

/// How a dispatched queued turn made its user message visible.
enum ClaudeQueuedDispatch() {
  /// The caller emitted the visible user message itself (slash commands emit
  /// a synthetic bubble); the queued entry is consumed immediately.
  emittedVisibleMessage,

  /// The CLI's replayed stdin echo will carry the visible user message; the
  /// queued entry is consumed when that echo arrives.
  awaitsUserEcho,
}

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
  Future<void> tail = Future<void>.value();
  int pending = 0;
  int generation = 0;
  int idleGeneration = 0;
  final List<_QueuedPrompt> queue = [];

  /// Prompt ids dispatched most recently, newest last. Bounds the idempotent
  /// retry window: a client that lost the acceptance response can re-send the
  /// same prompt id and be refused as an already-done no-op.
  final Queue<String> recentlyDispatched = Queue<String>();
}

/// Serializes Claude turns and owns session work/idle lifecycle policy plus
/// the bridge-owned queued-prompt state.
final class ClaudeSessionService({
  required final ClaudeSessionProcessRepository _processes,
  required final ClaudeApprovalRegistry _approvals,
  required final ServerClock _clock,
  required final Duration _idleTimeout,
}) {
  this {
    _processEvents = _processes.events.listen(_handleProcessEvent);
  }

  /// See [_SessionTurnState.recentlyDispatched]. 64 comfortably exceeds any
  /// realistic gap between a lost acceptance response and its retry (the
  /// retry fires on the next reconnect/refresh drain).
  static const int _recentlyDispatchedLimit = 64;

  final Map<String, _SessionTurnState> _turns = {};
  final Map<String, PluginSessionStatus> _retryStatuses = {};
  final StreamController<BridgeSseEvent> _events = StreamController.broadcast();
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.idle);
  final Set<Future<void>> _inFlightTeardowns = {};
  final Map<String, Future<void>> _teardownsBySession = {};
  late final StreamSubscription<ClaudeSessionProcessEvent> _processEvents;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => _events.stream;
  Stream<PluginWorkState> get workState => _workState.stream;
  PluginWorkState get currentWorkState => _workState.current;

  Map<String, PluginSessionStatus> get sessionStatuses => Map.unmodifiable({
    for (final entry in _turns.entries)
      entry.key:
          _retryStatuses[entry.key] ??
          (entry.value.pending > 0 ? const PluginSessionStatus.busy() : const PluginSessionStatus.idle()),
  });

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
  /// queued bubble in place.
  void consumeQueuedPrompt({required String sessionId, required String promptId}) {
    final state = _turns[sessionId];
    if (state == null) return;
    final index = state.queue.indexWhere((entry) => entry.id == promptId);
    if (index == -1) return;
    state.queue.removeAt(index);
    _emitQueueUpdate(sessionId: sessionId, state: state);
  }

  /// Queues a prompt or command turn and accepts it immediately.
  ///
  /// The returned future completes at enqueue — never after the turns ahead
  /// of it — so callers holding a client request open respond instantly. A
  /// [promptId] already queued or recently dispatched is an idempotent
  /// success no-op (the retry of a send whose response was lost).
  ///
  /// [onDispatched] runs right after the turn is written to the CLI and says
  /// how its user message becomes visible; the queued entry is consumed
  /// accordingly. Dispatch failures surface as a session error and remove
  /// the entry — acceptance is not revoked.
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
    required ClaudeQueuedDispatch Function() onDispatched,
  }) {
    if (_disposed || parts.isEmpty) {
      return Future.error(StateError("Claude session cannot accept the turn"));
    }
    final state = _turns.putIfAbsent(sessionId, _SessionTurnState.new);
    final isDuplicate =
        state.queue.any((entry) => entry.id == promptId) || state.recentlyDispatched.contains(promptId);
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
    state.tail = state.tail.then(
      (_) => _runTurn(
        sessionId: sessionId,
        directory: directory,
        createNew: createNew,
        parts: parts,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        state: state,
        generation: generation,
        mode: _QueuedTurnMode(entry: entry, onDispatched: onDispatched),
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
    state.tail = state.tail.then(
      (_) => _runTurn(
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
      _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const shared.SessionStatus.busy().toJson()));
      _emit(const BridgeSseProjectUpdated());
    }
  }

  Future<void> _runTurn({
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
      final dispatch = _processes.sendTurn(sessionId: sessionId, parts: parts);
      if (!dispatch.accepted) {
        throw StateError("Claude rejected the turn before dispatch");
      }
      switch (mode) {
        case _BlockingTurnMode(:final acceptance):
          if (!acceptance.isCompleted) acceptance.complete();
        case _QueuedTurnMode(:final entry, :final onDispatched):
          entry.dispatched = true;
          _recordDispatched(state: state, promptId: entry.id);
          if (onDispatched() == ClaudeQueuedDispatch.emittedVisibleMessage) {
            consumeQueuedPrompt(sessionId: sessionId, promptId: entry.id);
          }
      }
      final outcome = await dispatch.outcome;
      _settleQueuedEntry(sessionId: sessionId, state: state, mode: mode);
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        return _finish(sessionId, state, null);
      }
      _finish(sessionId, state, outcome);
    } on Object catch (error, stack) {
      mode.settleError(error, stack);
      _settleQueuedEntry(sessionId: sessionId, state: state, mode: mode);
      if (_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        Log.w("[claude] queued turn failed for $sessionId", error, stack);
        _finish(sessionId, state, const ClaudeTurnFailed());
      } else {
        _finish(sessionId, state, null);
      }
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
    if (!state.queue.contains(mode.entry)) return;
    state.queue.remove(mode.entry);
    _emitQueueUpdate(sessionId: sessionId, state: state);
  }

  Future<void> abort({required String sessionId}) async {
    final state = _turns[sessionId];
    if (state == null) return;
    if (state.pending == 0) {
      _approvals.cancelForSession(sessionId: sessionId);
      return;
    }
    state.generation++;
    state.idleGeneration++;
    if (state.queue.isNotEmpty) {
      state.queue.clear();
      _emitQueueUpdate(sessionId: sessionId, state: state);
    }
    _approvals.cancelForSession(sessionId: sessionId);
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
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        for (final entry in _turns.entries)
          if (entry.value.pending > 0) entry.key,
      };
      if (activeSessionIds.isEmpty) return const <String>{};
      await Future.wait([
        for (final sessionId in activeSessionIds) abort(sessionId: sessionId),
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
    }
    await _processEvents.cancel();
    _approvals.dispose();
    await _processes.dispose();
    await Future.wait(_inFlightTeardowns.toList(growable: false));
    await _events.close();
    await _workState.close();
  }

  bool _isCurrent({required String sessionId, required _SessionTurnState state, required int generation}) =>
      !_disposed && identical(_turns[sessionId], state) && state.generation == generation;

  void _finish(String sessionId, _SessionTurnState state, ClaudeTurnOutcome? outcome) {
    _retryStatuses.remove(sessionId);
    if (state.pending > 0) state.pending--;
    if (!identical(_turns[sessionId], state)) return;
    if (outcome is ClaudeTurnFailed) _emit(BridgeSseSessionError(sessionID: sessionId));
    if (state.pending == 0) {
      _emit(BridgeSseSessionIdle(sessionID: sessionId));
      _emit(const BridgeSseProjectUpdated());
      _syncWorkState();
      _scheduleIdleReap(sessionId: sessionId, state: state);
    }
  }

  void _scheduleIdleReap({required String sessionId, required _SessionTurnState state}) {
    final generation = ++state.idleGeneration;
    unawaited(() async {
      await _clock.delay(duration: _idleTimeout);
      if (_disposed ||
          !identical(_turns[sessionId], state) ||
          state.pending != 0 ||
          state.idleGeneration != generation) {
        return;
      }
      final teardown = _processes.teardown(sessionId: sessionId);
      _inFlightTeardowns.add(teardown);
      _teardownsBySession[sessionId] = teardown;
      try {
        await teardown;
      } finally {
        _inFlightTeardowns.remove(teardown);
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
      _workState.set(_turns.values.any((state) => state.pending > 0) ? PluginWorkState.busy : PluginWorkState.idle);

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
        final request = event.controlRequest;
        if (request != null) _approvals.handle(sessionId: event.sessionId, message: request);
      case ClaudeSessionProcessExited():
        _approvals.cancelForSession(sessionId: event.sessionId);
    }
  }
}

/// How one chained turn reports acceptance and visibility.
sealed class const _TurnMode() {
  /// Settles a turn that was dropped before dispatch (stale generation or a
  /// cancelled queued entry).
  void settleUnaccepted();

  /// Settles a turn whose dispatch threw.
  void settleError(Object error, StackTrace stack);
}

/// A queued-entry turn: accepted at enqueue, visible via [onDispatched].
final class const _QueuedTurnMode({
  required final _QueuedPrompt entry,
  required final ClaudeQueuedDispatch Function() onDispatched,
}) extends _TurnMode {
  @override
  void settleUnaccepted() {}

  @override
  void settleError(Object error, StackTrace stack) {}
}

/// The blocking initial turn: acceptance completes only at dispatch.
final class const _BlockingTurnMode({required final Completer<void> acceptance}) extends _TurnMode {
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
