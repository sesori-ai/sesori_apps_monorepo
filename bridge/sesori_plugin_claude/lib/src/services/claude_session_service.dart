import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../api/models/claude_stream_message.dart";
import "../claude_approval_registry.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";
import "../repositories/claude_session_process_repository.dart";

final class _SessionTurnState() {
  Future<void> tail = Future<void>.value();
  int pending = 0;
  int generation = 0;
  int idleGeneration = 0;

  /// True while the CLI runs a turn the bridge did not enqueue.
  ///
  /// A `ScheduleWakeup` loop wakeup starts a turn inside the resident process
  /// with no `enqueueTurn` call: frames stream while [pending] is zero. The
  /// flag keeps that turn visible (busy status, work state, abort) until its
  /// `result` frame lands.
  bool selfStarted = false;

  /// When the CLI's pending `ScheduleWakeup` timer fires, or null when none
  /// is scheduled.
  ///
  /// The timer lives only inside the resident process — killing the process
  /// kills the wakeup, and `--resume` does not rearm it (verified against CLI
  /// 2.1.233) — so the idle reap must not tear the process down before the
  /// wakeup fires.
  DateTime? wakeupAt;
}

/// Serializes Claude turns and owns session work/idle lifecycle policy.
final class ClaudeSessionService({
  required final ClaudeSessionProcessRepository _processes,
  required final ClaudeApprovalRegistry _approvals,
  required final ServerClock _clock,

  /// Resolves the current per-session idle timeout, or null when idle reaping
  /// is disabled. Read at every timer arm so a runtime settings change takes
  /// effect at the next idle transition.
  required final Duration? Function() _resolveIdleTimeout,
}) {
  this {
    _processEvents = _processes.events.listen(_handleProcessEvent);
  }

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
          (entry.value.pending > 0 || entry.value.selfStarted
              ? const PluginSessionStatus.busy()
              : const PluginSessionStatus.idle()),
  });

  Future<void> enqueueTurn({
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
    _retryStatuses.remove(sessionId);
    state.pending++;
    state.idleGeneration++;
    if (state.pending == 1) {
      _workState.set(PluginWorkState.busy);
      _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const shared.SessionStatus.busy().toJson()));
      _emit(const BridgeSseProjectUpdated());
    }
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
        acceptance: acceptance,
      ),
    );
    return acceptance.future;
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
    required Completer<void> acceptance,
  }) async {
    if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
      if (!acceptance.isCompleted) acceptance.completeError(StateError("Claude turn was cancelled before acceptance"));
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
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        if (!acceptance.isCompleted) {
          acceptance.completeError(StateError("Claude turn was cancelled before acceptance"));
        }
        return _finish(sessionId, state, null);
      }
      final dispatch = _processes.sendTurn(sessionId: sessionId, parts: parts);
      if (!dispatch.accepted) {
        throw StateError("Claude rejected the turn before dispatch");
      }
      if (!acceptance.isCompleted) acceptance.complete();
      final outcome = await dispatch.outcome;
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        return _finish(sessionId, state, null);
      }
      _finish(sessionId, state, outcome);
    } on Object catch (error, stack) {
      if (!acceptance.isCompleted) acceptance.completeError(error, stack);
      if (_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        Log.w("[claude] queued turn failed for $sessionId", error, stack);
        _finish(sessionId, state, const ClaudeTurnFailed());
      } else {
        _finish(sessionId, state, null);
      }
    }
  }

  Future<void> abort({required String sessionId}) async {
    final state = _turns[sessionId];
    if (state == null) return;
    if (state.pending == 0 && !state.selfStarted) {
      _approvals.cancelForSession(sessionId: sessionId);
      return;
    }
    state.generation++;
    state.idleGeneration++;
    // Teardown kills the CLI's in-process wakeup timer, and `--resume` does
    // not rearm it, so a pending wakeup cannot survive an abort.
    state.wakeupAt = null;
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
    if (state.selfStarted && identical(_turns[sessionId], state)) {
      _endSelfStartedTurn(sessionId: sessionId, state: state);
    }
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        for (final entry in _turns.entries)
          if (entry.value.pending > 0 || entry.value.selfStarted) entry.key,
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
    if (state.pending == 0 && !state.selfStarted) {
      _emit(BridgeSseSessionIdle(sessionID: sessionId));
      _emit(const BridgeSseProjectUpdated());
      _syncWorkState();
      _scheduleIdleReap(sessionId: sessionId, state: state);
    }
  }

  void _scheduleIdleReap({required String sessionId, required _SessionTurnState state}) {
    final generation = ++state.idleGeneration;
    final idleTimeout = _resolveIdleTimeout();
    if (idleTimeout == null) return;
    unawaited(() async {
      while (true) {
        await _clock.delay(duration: idleTimeout);
        if (_disposed ||
            !identical(_turns[sessionId], state) ||
            state.pending != 0 ||
            state.selfStarted ||
            state.idleGeneration != generation) {
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

  void _syncWorkState() => _workState.set(
    _turns.values.any((state) => state.pending > 0 || state.selfStarted)
        ? PluginWorkState.busy
        : PluginWorkState.idle,
  );

  void _emit(BridgeSseEvent event) {
    if (!_events.isClosed) _events.add(event);
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
        _trackWakeupSchedule(sessionId: event.sessionId, message: event.message);
        final request = event.controlRequest;
        if (request != null) _approvals.handle(sessionId: event.sessionId, message: request);
      case ClaudeSessionProcessExited():
        final state = _turns[event.sessionId];
        if (state != null) {
          // The wakeup timer died with the process and `--resume` does not
          // rearm it.
          state.wakeupAt = null;
          if (state.selfStarted) _endSelfStartedTurn(sessionId: event.sessionId, state: state);
        }
        _approvals.cancelForSession(sessionId: event.sessionId);
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
  /// content, or a permission ask. Bookkeeping frames (`init`, `status`,
  /// unknown types) do not, so post-turn stragglers cannot re-busy a session.
  void _trackSelfStartedTurn({required String sessionId, required ClaudeStreamMessage message}) {
    final state = _turns[sessionId];
    if (state == null) return;
    switch (message) {
      case ClaudeStreamEventMessage() || ClaudeAssistantMessage() || ClaudeControlRequestMessage():
        if (state.selfStarted || state.pending > 0) return;
        state.selfStarted = true;
        // A live turn supersedes the pending-wakeup estimate that started it.
        state.wakeupAt = null;
        state.idleGeneration++;
        _workState.set(PluginWorkState.busy);
        _emit(BridgeSseSessionStatus(sessionID: sessionId, status: const shared.SessionStatus.busy().toJson()));
        _emit(const BridgeSseProjectUpdated());
      case ClaudeResultMessage():
        if (state.selfStarted) _endSelfStartedTurn(sessionId: sessionId, state: state);
      case ClaudeStreamMessage():
        break;
    }
  }

  void _endSelfStartedTurn({required String sessionId, required _SessionTurnState state}) {
    state.selfStarted = false;
    if (state.pending != 0) return;
    _emit(BridgeSseSessionIdle(sessionID: sessionId));
    _emit(const BridgeSseProjectUpdated());
    _syncWorkState();
    _scheduleIdleReap(sessionId: sessionId, state: state);
  }
}
