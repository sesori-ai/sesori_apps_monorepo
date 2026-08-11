import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../claude_approval_registry.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";
import "../repositories/claude_session_process_repository.dart";

final class _SessionTurnState {
  Future<void> tail = Future<void>.value();
  int pending = 0;
  int generation = 0;
  int idleGeneration = 0;
}

/// Serializes Claude turns and owns session work/idle lifecycle policy.
final class ClaudeSessionService {
  ClaudeSessionService({
    required ClaudeSessionProcessRepository processes,
    required ClaudeApprovalRegistry approvals,
    required ServerClock clock,
    required Duration idleTimeout,
  }) : _processes = processes,
       _approvals = approvals,
       _clock = clock,
       _idleTimeout = idleTimeout {
    _processEvents = _processes.events.listen(_handleProcessEvent);
  }

  final ClaudeSessionProcessRepository _processes;
  final ClaudeApprovalRegistry _approvals;
  final ServerClock _clock;
  final Duration _idleTimeout;
  final Map<String, _SessionTurnState> _turns = {};
  final StreamController<BridgeSseEvent> _events = StreamController.broadcast();
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.idle);
  final Set<Future<void>> _inFlightTeardowns = {};
  late final StreamSubscription<ClaudeSessionProcessEvent> _processEvents;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => _events.stream;
  Stream<PluginWorkState> get workState => _workState.stream;
  PluginWorkState get currentWorkState => _workState.current;

  Map<String, PluginSessionStatus> get sessionStatuses => Map.unmodifiable({
    for (final entry in _turns.entries)
      entry.key: entry.value.pending > 0 ? const PluginSessionStatus.busy() : const PluginSessionStatus.idle(),
  });

  void enqueueTurn({
    required String sessionId,
    required String directory,
    required bool createNew,
    required List<PluginPromptPart> parts,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
  }) {
    if (_disposed || parts.isEmpty) return;
    final state = _turns.putIfAbsent(sessionId, _SessionTurnState.new);
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
      ),
    );
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
  }) async {
    if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) return _finish(sessionId, state, null);
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
        return _finish(sessionId, state, null);
      }
      final outcome = await _processes.sendTurn(sessionId: sessionId, parts: parts);
      if (!_isCurrent(sessionId: sessionId, state: state, generation: generation)) {
        return _finish(sessionId, state, null);
      }
      _finish(sessionId, state, outcome);
    } on Object catch (error, stack) {
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
    if (state.pending == 0) {
      _approvals.cancelForSession(sessionId: sessionId);
      return;
    }
    state.generation++;
    state.idleGeneration++;
    _approvals.cancelForSession(sessionId: sessionId);
    try {
      await _processes.interrupt(sessionId: sessionId);
    } on Object catch (error, stack) {
      Log.w("[claude] interrupt failed for $sessionId", error, stack);
    }
  }

  Future<void> deleteSession({required String sessionId}) async {
    final state = _turns.remove(sessionId);
    if (state != null) {
      state.generation++;
      state.idleGeneration++;
    }
    _approvals.forgetSession(sessionId: sessionId);
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
      try {
        await teardown;
      } finally {
        _inFlightTeardowns.remove(teardown);
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

  void _handleProcessEvent(ClaudeSessionProcessEvent event) {
    switch (event) {
      case final ClaudeSessionProcessMessage event:
        final request = event.controlRequest;
        if (request != null) _approvals.handle(message: request);
      case ClaudeSessionProcessExited():
        _approvals.cancelForSession(sessionId: event.sessionId);
    }
  }
}
