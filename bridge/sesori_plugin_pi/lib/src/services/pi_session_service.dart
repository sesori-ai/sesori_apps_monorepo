import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../api/models/pi_event.dart";
import "../api/models/pi_extension_ui_request.dart";
import "../api/models/pi_rpc_frame.dart";
import "../api/pi_rpc_client.dart";
import "../repositories/pi_session_catalog_repository.dart";
import "../repositories/pi_session_process_repository.dart";
import "pi_event_dispatcher.dart";
import "pi_extension_ui_service.dart";

final class const PiSessionBusyException({required final String sessionId}) implements Exception {
  @override
  String toString() => "Pi session is busy";
}

final class const PiTurnCancelledException({required final String sessionId}) implements Exception {
  @override
  String toString() => "Pi turn was cancelled";
}

final class _PiSessionTurnState({required final String initialDirectory}) {
  String directory = initialDirectory;
  final List<_PiTurn> queue = [];
  _PiTurn? active;
  Future<void>? idleReap;
  PluginSessionStatus status = const PluginSessionStatus.idle();
  int generation = 0;
  int idleGeneration = 0;
}

final class _PiTurn({
  required final PiPromptPayload payload,
  required final ({String providerID, String modelID})? model,
  required final PluginSessionVariant? variant,
  required final String? userVisibleText,
  required final Completer<void>? commandAcceptance,
}) {
  PiSessionConnection? connection;
  bool promptDispatched = false;
  bool responseSucceeded = false;
  bool agentStarted = false;
  bool agentSettled = false;
  bool settled = false;
}

final class PiSessionService({
  required final PiSessionProcessRepository processRepository,
  required final PiSessionCatalogRepository catalogRepository,
  required final PiEventDispatcher eventDispatcher,
  required final PiExtensionUiService extensionUiService,
  required final ServerClock clock,
  required final Duration idleTimeout,
}) {
  this {
    _frameSubscription = _processes.frames.listen(_handleFrame);
    _exitSubscription = _processes.exits.listen(_handleExit);
  }

  final PiSessionProcessRepository _processes = processRepository;
  final PiSessionCatalogRepository _catalog = catalogRepository;
  final PiEventDispatcher _dispatcher = eventDispatcher;
  final PiExtensionUiService _extensionUi = extensionUiService;
  final ServerClock _clock = clock;
  final Duration _idleTimeout = idleTimeout;
  final Map<String, _PiSessionTurnState> _sessions = {};
  final Map<String, String> _pendingNewDirectories = {};
  final Set<Future<void>> _activeIdleReaps = {};
  final StreamController<BridgeSseEvent> _events = StreamController.broadcast();
  final PluginWorkStateController _workState = PluginWorkStateController(initial: PluginWorkState.idle);
  late final StreamSubscription<PiSessionProcessFrame> _frameSubscription;
  late final StreamSubscription<PiSessionProcessExit> _exitSubscription;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => _events.stream;
  Stream<PluginWorkState> get workState => _workState.stream;
  PluginWorkState get currentWorkState => _workState.current;

  String? directoryForSession({required String sessionId}) =>
      _sessions[sessionId]?.directory ?? _pendingNewDirectories[sessionId];

  Future<String> prepareNewSession({required String directory, required String? parentSessionId}) async {
    if (_disposed) throw const PiRpcDisposedException();
    final sessionId = _processes.generateSessionId();
    final parent = parentSessionId == null ? null : await _catalog.findSessionById(sessionId: parentSessionId);
    await _processes.markPendingNew(
      sessionId: sessionId,
      directory: directory,
      parentSessionId: parentSessionId,
      parentDirectory: parent?.directory,
    );
    _pendingNewDirectories[sessionId] = directory;
    return sessionId;
  }

  Map<String, PluginSessionStatus> get sessionStatuses =>
      Map.unmodifiable({for (final entry in _sessions.entries) entry.key: entry.value.status});

  Future<void> deleteSession({required PluginSession root}) async {
    final sessions = await _catalog.listAllSessions(knownDirectories: {root.directory});
    final descendants = _descendantIds(rootId: root.id, sessions: sessions);
    for (final affected in [root.id, ...descendants]) {
      await forgetSession(sessionId: affected);
      _catalog.forgetSession(sessionId: affected);
    }
    await _processes.deletePersistedSession(sessionId: root.id, directory: root.directory);
  }

  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final statuses = sessionStatuses;
    final sessions = _catalog.sessionSnapshot;
    final activeIds = <String>{};
    for (final entry in statuses.entries) {
      final running = entry.value is PluginSessionStatusBusy || entry.value is PluginSessionStatusRetry;
      final awaitingInput = _extensionUi.getPendingQuestions(sessionId: entry.key).isNotEmpty;
      if (running || awaitingInput) activeIds.add(entry.key);
    }
    final rootIds = <String>{};
    for (final sessionId in activeIds) {
      var rootId = sessionId;
      final visited = {sessionId};
      while (true) {
        final parent = sessions[rootId]?.parentID;
        if (parent == null || !visited.add(parent)) break;
        rootId = parent;
      }
      rootIds.add(rootId);
    }
    final byProject = <String, List<PluginActiveSession>>{};
    for (final rootId in rootIds) {
      final status = statuses[rootId];
      final directory = sessions[rootId]?.directory ?? directoryForSession(sessionId: rootId);
      if (directory == null) continue;
      final descendants = _descendantIds(rootId: rootId, sessions: sessions.values.toList());
      final activeDescendants = [
        for (final id in descendants)
          if (activeIds.contains(id)) id,
      ];
      final activeFamilyIds = [rootId, ...activeDescendants];
      (byProject[directory] ??= []).add(
        PluginActiveSession(
          id: rootId,
          mainAgentRunning: status is PluginSessionStatusBusy || status is PluginSessionStatusRetry,
          awaitingInput: activeFamilyIds.any(
            (sessionId) => _extensionUi.getPendingQuestions(sessionId: sessionId).isNotEmpty,
          ),
          isRetrying: activeFamilyIds.any((sessionId) => statuses[sessionId] is PluginSessionStatusRetry),
          childSessionIds: activeDescendants,
        ),
      );
    }
    return [
      for (final entry in byProject.entries) PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  Future<void> sendPrompt({
    required String sessionId,
    required String directory,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    if (_disposed) return Future.error(const PiRpcDisposedException());
    final payload = _processes.mapPrompt(parts: parts, userVisibleText: userVisibleText);
    _admit(
      sessionId: sessionId,
      directory: directory,
      turn: _PiTurn(
        payload: payload,
        model: model,
        variant: variant,
        userVisibleText: userVisibleText,
        commandAcceptance: null,
      ),
    );
    return Future.value();
  }

  Future<void> sendCommand({
    required String sessionId,
    required String directory,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    if (_disposed) return Future.error(const PiRpcDisposedException());
    final state = _sessions[sessionId];
    if (state?.active != null || (state?.queue.isNotEmpty ?? false)) {
      return Future.error(PiSessionBusyException(sessionId: sessionId));
    }
    final execution = arguments.isEmpty ? "/$command" : "/$command $arguments";
    final visibleArguments = userVisibleArguments;
    final visible = visibleArguments == null || visibleArguments.isEmpty ? "/$command" : "/$command $visibleArguments";
    final acceptance = Completer<void>();
    final payload = PiPromptPayload(message: execution, images: const []);
    _admit(
      sessionId: sessionId,
      directory: directory,
      turn: _PiTurn(
        payload: payload,
        model: model,
        variant: variant,
        userVisibleText: visible,
        commandAcceptance: acceptance,
      ),
    );
    return acceptance.future;
  }

  void _admit({required String sessionId, required String directory, required _PiTurn turn}) {
    final state = _sessions.putIfAbsent(sessionId, () => _PiSessionTurnState(initialDirectory: directory));
    state.directory = directory;
    state.idleGeneration++;
    state.queue.add(turn);
    if (state.active == null && state.queue.length == 1) {
      state.status = const PluginSessionStatus.busy();
      _emit(
        BridgeSseSessionStatus(
          sessionID: sessionId,
          status: const shared.SessionStatus.busy().toJson(),
        ),
      );
      _emit(const BridgeSseProjectUpdated());
    }
    _syncWorkState();
    _startNext(sessionId: sessionId, state: state);
  }

  void _startNext({required String sessionId, required _PiSessionTurnState state}) {
    if (_disposed || state.active != null || state.queue.isEmpty || !identical(_sessions[sessionId], state)) return;
    final turn = state.queue.removeAt(0);
    state.active = turn;
    final generation = state.generation;
    unawaited(_runTurn(sessionId: sessionId, state: state, turn: turn, generation: generation));
  }

  Future<void> _runTurn({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
    required int generation,
  }) async {
    try {
      final idleReap = state.idleReap;
      if (idleReap != null) await idleReap;
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) {
        throw PiTurnCancelledException(sessionId: sessionId);
      }
      final connection = await _processes.ensureResident(
        sessionId: sessionId,
        knownDirectories: {state.directory},
      );
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) {
        throw PiTurnCancelledException(sessionId: sessionId);
      }
      turn.connection = connection;
      await _processes.applySelection(
        sessionId: sessionId,
        connection: connection,
        model: turn.model,
        variant: turn.variant,
      );
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) {
        throw PiTurnCancelledException(sessionId: sessionId);
      }
      _dispatcher.beginTurn(
        sessionId: sessionId,
        executionText: turn.payload.message,
        userVisibleText: turn.userVisibleText,
      );
      turn.promptDispatched = true;
      final response = _processes.dispatchPrompt(connection: connection, payload: turn.payload);
      await response;
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      turn.responseSucceeded = true;
      final acceptance = turn.commandAcceptance;
      if (acceptance != null && !acceptance.isCompleted) acceptance.complete();
      await Future<void>.delayed(Duration.zero);
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      if (turn.agentSettled) {
        _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
      } else if (!turn.agentStarted) {
        final agentState = await _processes.getState(connection: connection);
        await Future<void>.delayed(Duration.zero);
        if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
        if (!turn.agentStarted && !agentState.streaming && agentState.pendingMessageCount == 0) {
          _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
        }
      }
    } on PiTurnCancelledException catch (error, stack) {
      final acceptance = turn.commandAcceptance;
      if (acceptance != null && !acceptance.isCompleted) acceptance.completeError(error, stack);
    } on Object catch (error, stack) {
      if (error is PiRpcProcessExitException) {
        await Future<void>.delayed(Duration.zero);
        if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      }
      if (error is TimeoutException && turn.promptDispatched) {
        final connection = turn.connection;
        if (connection != null) {
          _extensionUi.cancelForOwner(
            sessionId: sessionId,
            processGeneration: connection.generation,
          );
          await _processes.teardownConnection(connection: connection);
          if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
        }
      }
      final acceptance = turn.commandAcceptance;
      if (acceptance != null && !acceptance.isCompleted) acceptance.completeError(error, stack);
      if (_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) {
        final presented = _processes.presentTurnFailure(sessionId: sessionId, error: error);
        Log.w("[pi] admitted turn failed for session id=$sessionId", presented.cause, stack);
        if (presented.message?.contains("/login") ?? false) {
          _emit(
            BridgeSseTuiToastShow(
              title: "Pi login required",
              message: presented.message,
              variant: "warning",
            ),
          );
        }
        _finish(sessionId: sessionId, state: state, turn: turn, failed: true, failure: error);
      }
    }
  }

  void _handleFrame(PiSessionProcessFrame processFrame) {
    final state = _sessions[processFrame.sessionId];
    final turn = state?.active;
    if (state == null || turn == null) return;
    turn.connection ??= PiSessionConnection(
      sessionId: processFrame.sessionId,
      generation: processFrame.generation,
    );
    if (turn.connection?.generation != processFrame.generation) return;
    switch (processFrame.frame) {
      case PiEventFrame(:final event):
        if (turn.promptDispatched && event is PiAgentStartEvent) turn.agentStarted = true;
        final now = _clock.now();
        final mappedStatus = _dispatcher.sessionStatusFor(event: event, now: now);
        final statusChanged =
            mappedStatus != null &&
            event is! PiAgentStartEvent &&
            event is! PiAgentSettledEvent &&
            state.status != mappedStatus;
        if (statusChanged) state.status = mappedStatus;
        for (final mapped in _dispatcher.map(sessionId: processFrame.sessionId, event: event, now: now)) {
          final serviceOwnsLifecycle =
              (event is PiAgentStartEvent || event is PiAgentSettledEvent) &&
              (mapped is BridgeSseSessionStatus || mapped is BridgeSseSessionIdle);
          if (!serviceOwnsLifecycle) _emit(mapped);
        }
        if (statusChanged) _emit(const BridgeSseProjectUpdated());
        if (turn.promptDispatched && event is PiAgentSettledEvent) {
          turn.agentSettled = true;
          if (turn.responseSucceeded) {
            _finish(
              sessionId: processFrame.sessionId,
              state: state,
              turn: turn,
              failed: false,
              failure: null,
            );
          }
        }
      case PiExtensionUiFrame(:final request):
        final acceptance = turn.commandAcceptance;
        if (turn.promptDispatched &&
            request is PiExtensionDialogRequest &&
            acceptance != null &&
            !acceptance.isCompleted) {
          acceptance.complete();
        }
        unawaited(
          _extensionUi
              .handleRequest(
                ownerSessionId: processFrame.sessionId,
                processGeneration: processFrame.generation,
                request: request,
              )
              .catchError(
                (Object error, StackTrace stack) {
                  Log.w("[pi] extension UI routing failed for session id=${processFrame.sessionId}", error, stack);
                },
              ),
        );
      case PiResponseFrame() || PiUnknownFrame():
        break;
    }
  }

  void _handleExit(PiSessionProcessExit exit) {
    _extensionUi.cancelForOwner(sessionId: exit.sessionId, processGeneration: exit.generation);
    final state = _sessions[exit.sessionId];
    final turn = state?.active;
    if (state == null || turn == null || turn.connection?.generation != exit.generation) return;
    if (exit.authUnavailable) {
      _emit(
        const BridgeSseTuiToastShow(
          title: "Pi login required",
          message: "Pi has no model available. Run Pi locally and use /login, then try again.",
          variant: "warning",
        ),
      );
    }
    final failure = PiRpcProcessExitException(exitCode: exit.exitCode);
    Log.w("[pi] resident process exited during active turn for session id=${exit.sessionId}", failure);
    _finish(
      sessionId: exit.sessionId,
      state: state,
      turn: turn,
      failed: true,
      failure: failure,
    );
  }

  void _finish({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
    required bool failed,
    required Object? failure,
  }) {
    if (turn.settled) return;
    turn.settled = true;
    final acceptance = turn.commandAcceptance;
    if (acceptance != null && !acceptance.isCompleted && failed) {
      acceptance.completeError(failure ?? StateError("Pi command failed before acceptance"), StackTrace.current);
    }
    if (!identical(_sessions[sessionId], state) || !identical(state.active, turn)) return;
    state.active = null;
    if (failed) _emit(BridgeSseSessionError(sessionID: sessionId));
    unawaited(_clearPendingWhenPersisted(sessionId: sessionId, directory: state.directory));
    if (state.queue.isNotEmpty) {
      final statusChanged = state.status != const PluginSessionStatus.busy();
      state.status = const PluginSessionStatus.busy();
      if (statusChanged) _emit(const BridgeSseProjectUpdated());
      _startNext(sessionId: sessionId, state: state);
      return;
    }
    state.status = const PluginSessionStatus.idle();
    _emit(
      BridgeSseSessionStatus(
        sessionID: sessionId,
        status: const shared.SessionStatus.idle().toJson(),
      ),
    );
    _emit(BridgeSseSessionIdle(sessionID: sessionId));
    _emit(const BridgeSseProjectUpdated());
    _syncWorkState();
    _scheduleIdleReap(sessionId: sessionId, state: state);
  }

  Future<void> _clearPendingWhenPersisted({required String sessionId, required String directory}) async {
    try {
      if (await _processes.clearPendingWhenPersisted(
        sessionId: sessionId,
        knownDirectories: {directory},
      )) {
        _pendingNewDirectories.remove(sessionId);
      }
    } on Object catch (error, stack) {
      Log.w("[pi] failed to clear persisted pending marker for session id=$sessionId", error, stack);
    }
  }

  Future<void> abort({required String sessionId}) async {
    final state = _sessions[sessionId];
    if (state == null) {
      await _processes.teardown(sessionId: sessionId);
      return;
    }
    state.generation++;
    state.idleGeneration++;
    final cancelled = [?state.active, ...state.queue];
    state.active = null;
    state.queue.clear();
    state.status = const PluginSessionStatus.idle();
    for (final turn in cancelled) {
      final acceptance = turn.commandAcceptance;
      if (acceptance != null && !acceptance.isCompleted) {
        acceptance.completeError(PiTurnCancelledException(sessionId: sessionId), StackTrace.current);
      }
    }
    _extensionUi.cancelForOwner(sessionId: sessionId, processGeneration: null);
    final connection = cancelled.firstOrNull?.connection;
    try {
      final idleReap = state.idleReap;
      if (idleReap != null) await idleReap;
      if (connection != null) await _processes.abort(connection: connection);
    } on Object catch (error, stack) {
      Log.w("[pi] abort command failed for session id=$sessionId", error, stack);
    } finally {
      await _processes.teardown(sessionId: sessionId);
    }
    _emit(
      BridgeSseSessionStatus(
        sessionID: sessionId,
        status: const shared.SessionStatus.idle().toJson(),
      ),
    );
    _emit(BridgeSseSessionIdle(sessionID: sessionId));
    _emit(const BridgeSseProjectUpdated());
    _syncWorkState();
    _scheduleIdleReap(sessionId: sessionId, state: state);
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    return () async {
      final activeSessionIds = <String>{
        for (final entry in _sessions.entries)
          if (entry.value.active != null || entry.value.queue.isNotEmpty) entry.key,
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

  Future<void> forgetSession({required String sessionId}) async {
    final state = _sessions.remove(sessionId);
    if (state != null) {
      state.generation++;
      state.idleGeneration++;
      for (final turn in [?state.active, ...state.queue]) {
        final acceptance = turn.commandAcceptance;
        if (acceptance != null && !acceptance.isCompleted) {
          acceptance.completeError(PiTurnCancelledException(sessionId: sessionId), StackTrace.current);
        }
      }
      state.active = null;
      state.queue.clear();
    }
    final idleReap = state?.idleReap;
    if (idleReap != null) {
      try {
        await idleReap;
      } on Object catch (error, stackTrace) {
        Log.w("[pi] idle process teardown failed while forgetting $sessionId", error, stackTrace);
      }
    }
    _extensionUi.cancelForOwner(sessionId: sessionId, processGeneration: null);
    final pendingDirectory = _pendingNewDirectories.remove(sessionId);
    await _processes.forgetSession(
      sessionId: sessionId,
      knownDirectories: {?state?.directory, ?pendingDirectory},
    );
    _dispatcher.forgetSession(sessionId: sessionId);
    _syncWorkState();
  }

  Set<String> _descendantIds({required String rootId, required List<PluginSession> sessions}) {
    final children = <String, List<String>>{};
    for (final session in sessions) {
      final parent = session.parentID;
      if (parent != null) (children[parent] ??= []).add(session.id);
    }
    final descendants = <String>{};
    final pending = [...?children[rootId]];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!descendants.add(id)) continue;
      pending.addAll(children[id] ?? const []);
    }
    return descendants;
  }

  void _scheduleIdleReap({required String sessionId, required _PiSessionTurnState state}) {
    final generation = ++state.idleGeneration;
    unawaited(() async {
      await _clock.delay(duration: _idleTimeout);
      if (_disposed ||
          !identical(_sessions[sessionId], state) ||
          state.active != null ||
          state.queue.isNotEmpty ||
          state.idleGeneration != generation) {
        return;
      }
      _extensionUi.cancelForOwner(sessionId: sessionId, processGeneration: null);
      final teardown = _processes.teardown(sessionId: sessionId);
      state.idleReap = teardown;
      _activeIdleReaps.add(teardown);
      try {
        await teardown;
      } finally {
        if (identical(state.idleReap, teardown)) state.idleReap = null;
        _activeIdleReaps.remove(teardown);
      }
      if (identical(_sessions[sessionId], state) && state.idleGeneration == generation) {
        _sessions.remove(sessionId);
      }
    }());
  }

  bool _isCurrent({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
    required int generation,
  }) =>
      !_disposed &&
      identical(_sessions[sessionId], state) &&
      identical(state.active, turn) &&
      state.generation == generation;

  void _syncWorkState() => _workState.set(
    _sessions.values.any((state) => state.active != null || state.queue.isNotEmpty)
        ? PluginWorkState.busy
        : PluginWorkState.idle,
  );

  void _emit(BridgeSseEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> dispose({Duration shutdownBudget = const Duration(seconds: 15)}) =>
      _disposeFuture ??= _dispose(shutdownBudget: shutdownBudget);

  Future<void> _dispose({required Duration shutdownBudget}) async {
    _disposed = true;
    for (final state in _sessions.values) {
      state.generation++;
      state.idleGeneration++;
      for (final turn in [?state.active, ...state.queue]) {
        final acceptance = turn.commandAcceptance;
        if (acceptance != null && !acceptance.isCompleted) {
          acceptance.completeError(const PiRpcDisposedException(), StackTrace.current);
        }
      }
    }
    await _frameSubscription.cancel();
    await _exitSubscription.cancel();
    await _extensionUi.dispose();
    await _processes.dispose(shutdownBudget: shutdownBudget);
    _sessions.clear();
    _pendingNewDirectories.clear();
    await _events.close();
    await _workState.close();
  }
}
