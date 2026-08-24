import "dart:async";
import "dart:collection";

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

enum _PiQueueState() { visible, released, cancelled }

final class _PiSessionTurnState({required final String initialDirectory}) {
  /// See [recentPromptIds]. 64 comfortably exceeds any realistic gap between
  /// a lost acceptance response and its retry.
  static const int _recentPromptIdLimit = 64;

  String directory = initialDirectory;

  /// Admitted turns waiting for their FIFO dispatch attempt.
  final List<_PiTurn> queue = [];

  /// Prompt commands accepted by Pi and governed by its current agent run.
  final List<_PiTurn> inFlight = [];

  /// The one turn currently connecting, selecting, or awaiting prompt acceptance.
  _PiTurn? active;
  Future<void>? idleReap;
  PluginSessionStatus status = const PluginSessionStatus.idle();
  bool agentRunning = false;
  int generation = 0;
  int idleGeneration = 0;

  /// Settled turns' prompt ids, retained so the retry of a send whose
  /// response was lost is an idempotent no-op instead of a duplicate turn.
  /// Active and queued turns carry their id and are checked live, so only
  /// settled ids need this bounded window.
  final Queue<String> recentPromptIds = Queue<String>();

  List<_PiTurn> get turns {
    final result = List<_PiTurn>.of(inFlight);
    final activeTurn = active;
    if (activeTurn != null) result.add(activeTurn);
    result.addAll(queue);
    return result;
  }

  bool get hasWork => active != null || inFlight.isNotEmpty || queue.isNotEmpty;

  bool isAdmitted({required String promptId}) =>
      turns.any(
        (turn) =>
            turn.promptId == promptId &&
            (turn is! _PiQueuedPromptTurn || turn.queueState != _PiQueueState.cancelled),
      ) ||
      recentPromptIds.contains(promptId);

  void recordSettledPromptId({required String promptId}) {
    recentPromptIds.addLast(promptId);
    while (recentPromptIds.length > _recentPromptIdLimit) {
      recentPromptIds.removeFirst();
    }
  }
}

sealed class _PiTurn({
  required final String promptId,
  required final PiPromptPayload payload,
  required final ({String providerID, String modelID})? model,
  required final PluginSessionVariant? variant,
  required final String? userVisibleText,
}) {
  PiSessionConnection? connection;
  bool promptDispatched = false;
  bool userMessageEmitted = false;
  bool responseSucceeded = false;
  bool agentStarted = false;
  bool agentSettled = false;
  bool settlementObservedBeforeAcceptance = false;
  bool settled = false;
}

final class _PiInitialTurn({
  required super.promptId,
  required super.payload,
  required super.model,
  required super.variant,
  required super.userVisibleText,
}) extends _PiTurn;

final class _PiQueuedPromptTurn({
  required super.promptId,
  required super.payload,
  required super.model,
  required super.variant,
  required super.userVisibleText,
  required final PluginQueuedPrompt presentation,
}) extends _PiTurn {
  _PiQueueState queueState = _PiQueueState.visible;
}

final class _PiCommandTurn({
  required super.promptId,
  required super.payload,
  required super.model,
  required super.variant,
  required super.userVisibleText,
  required final Completer<void> acceptance,
}) extends _PiTurn;

final class PiSessionService({
  required final PiSessionProcessRepository processRepository,
  required final PiSessionCatalogRepository catalogRepository,
  required final PiEventDispatcher eventDispatcher,
  required final PiExtensionUiService extensionUiService,
  required final ServerClock clock,
  required final Duration? Function() resolveIdleTimeout,
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
  final Duration? Function() _resolveIdleTimeout = resolveIdleTimeout;
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

  List<PluginQueuedPrompt> queuedPrompts({required String sessionId}) {
    final state = _sessions[sessionId];
    if (state == null) return const [];
    return [
      for (final turn in state.turns)
        if (turn is _PiQueuedPromptTurn && turn.queueState == _PiQueueState.visible) turn.presentation,
    ];
  }

  List<PluginMessageWithParts> withLiveMessages({
    required String sessionId,
    required List<PluginMessageWithParts> history,
  }) {
    final activeCompaction = _dispatcher.activeCompactionMessage(sessionId: sessionId);
    if (activeCompaction == null || history.any((message) => message.info.id == activeCompaction.info.id)) {
      return history;
    }
    return [...history, activeCompaction];
  }

  bool cancelQueuedPrompt({required String sessionId, required String promptId}) {
    final state = _sessions[sessionId];
    if (state == null) return false;
    final active = state.active;
    if (active is _PiQueuedPromptTurn &&
        active.promptId == promptId &&
        !active.promptDispatched &&
        active.queueState == _PiQueueState.visible) {
      _cancelQueuedPresentation(sessionId: sessionId, state: state, turn: active);
      return true;
    }
    final index = state.queue.indexWhere(
      (turn) =>
          turn is _PiQueuedPromptTurn &&
          turn.promptId == promptId &&
          turn.queueState == _PiQueueState.visible,
    );
    if (index == -1) return false;
    final turn = state.queue.removeAt(index) as _PiQueuedPromptTurn;
    _cancelQueuedPresentation(sessionId: sessionId, state: state, turn: turn);
    _startNext(sessionId: sessionId, state: state);
    return true;
  }

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
    required String promptId,
    required String directory,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    if (_disposed) return Future.error(const PiRpcDisposedException());
    final visibleText = userVisibleText?.trim();
    final payload = _processes.mapPrompt(parts: parts, userVisibleText: userVisibleText);
    _admit(
      sessionId: sessionId,
      directory: directory,
      turn: _PiQueuedPromptTurn(
        promptId: promptId,
        payload: payload,
        model: model,
        variant: variant,
        userVisibleText: userVisibleText,
        presentation: PluginQueuedPrompt(
          id: promptId,
          text: visibleText == null || visibleText.isEmpty ? null : visibleText,
          command: null,
          attachmentCount: parts.where((part) => part is! PluginPromptPartText).length,
          createdAt: _clock.now().millisecondsSinceEpoch,
        ),
      ),
    );
    return Future.value();
  }

  Future<void> sendInitialPrompt({
    required String sessionId,
    required String promptId,
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
      turn: _PiInitialTurn(
        promptId: promptId,
        payload: payload,
        model: model,
        variant: variant,
        userVisibleText: userVisibleText,
      ),
    );
    return Future.value();
  }

  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String directory,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    if (_disposed) return Future.error(const PiRpcDisposedException());
    final state = _sessions[sessionId];
    if (state != null && state.isAdmitted(promptId: promptId)) return Future.value();
    if (state?.hasWork ?? false) {
      return Future.error(PiSessionBusyException(sessionId: sessionId));
    }
    final execution = arguments.isEmpty ? "/$command" : "/$command $arguments";
    final visibleArguments = userVisibleArguments?.trim();
    final visible = visibleArguments == null || visibleArguments.isEmpty
        ? "/$command"
        : "/$command $userVisibleArguments";
    final acceptance = Completer<void>();
    final payload = PiPromptPayload(message: execution, images: const []);
    _admit(
      sessionId: sessionId,
      directory: directory,
      turn: _PiCommandTurn(
        promptId: promptId,
        payload: payload,
        model: model,
        variant: variant,
        userVisibleText: visible,
        acceptance: acceptance,
      ),
    );
    return acceptance.future;
  }

  void _admit({required String sessionId, required String directory, required _PiTurn turn}) {
    final state = _sessions.putIfAbsent(sessionId, () => _PiSessionTurnState(initialDirectory: directory));
    if (state.isAdmitted(promptId: turn.promptId)) {
      // The retry of a send whose response was lost: the turn is already
      // admitted (queued, running, or finished), so accept idempotently.
      if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
        turn.acceptance.complete();
      }
      return;
    }
    state.directory = directory;
    state.idleGeneration++;
    final wasIdle = !state.hasWork;
    state.queue.add(turn);
    if (wasIdle) {
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
    if (turn is _PiQueuedPromptTurn) _emitQueueUpdate(sessionId: sessionId, state: state);
    _startNext(sessionId: sessionId, state: state);
  }

  void _startNext({required String sessionId, required _PiSessionTurnState state}) {
    if (_disposed || state.active != null || state.queue.isEmpty || !identical(_sessions[sessionId], state)) return;
    if (state.inFlight.isNotEmpty && _changesSelection(inFlight: state.inFlight, next: state.queue.first)) return;
    final turn = state.queue.removeAt(0);
    state.active = turn;
    final generation = state.generation;
    unawaited(_runTurn(sessionId: sessionId, state: state, turn: turn, generation: generation));
  }

  bool _changesSelection({required List<_PiTurn> inFlight, required _PiTurn next}) {
    ({String providerID, String modelID})? effectiveModel;
    String? effectiveVariant;
    for (final turn in inFlight) {
      final requestedModel = turn.model;
      if (requestedModel != null && requestedModel != effectiveModel) {
        effectiveModel = requestedModel;
        effectiveVariant = null;
      }
      final requestedVariant = turn.variant?.id;
      if (requestedVariant != null) effectiveVariant = requestedVariant;
    }
    final nextModel = next.model;
    if (nextModel != null && nextModel != effectiveModel) return true;
    final nextVariant = next.variant?.id;
    return nextVariant != null && nextVariant != effectiveVariant;
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
      _dispatcher.registerPrompt(
        sessionId: sessionId,
        promptId: turn.promptId,
        executionText: turn.payload.message,
        userVisibleText: turn.userVisibleText,
      );
      turn
        ..promptDispatched = true
        ..agentStarted = state.agentRunning;
      await _processes.dispatchPrompt(connection: connection, payload: turn.payload);
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      turn.responseSucceeded = true;
      if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
        turn.acceptance.complete();
      }
      await Future<void>.delayed(Duration.zero);
      if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      if (turn.agentSettled) {
        _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
        return;
      }
      if (turn.settlementObservedBeforeAcceptance || !turn.agentStarted) {
        final agentState = await _processes.getState(connection: connection);
        await Future<void>.delayed(Duration.zero);
        if (!_isCurrent(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
        if (turn.agentSettled) {
          _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
          return;
        }
        final hasAgentWork = agentState.streaming || agentState.pendingMessageCount > 0;
        if (!hasAgentWork) {
          _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
          return;
        }
        turn
          ..agentStarted = true
          ..settlementObservedBeforeAcceptance = false;
        state.agentRunning = state.agentRunning || agentState.streaming;
      }
      _moveInFlight(sessionId: sessionId, state: state, turn: turn);
    } on PiTurnCancelledException catch (error, stack) {
      if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
        turn.acceptance.completeError(error, stack);
      }
      if (_ownsTurn(sessionId: sessionId, state: state, turn: turn, generation: generation)) {
        _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
      }
    } on Object catch (error, stack) {
      if (error is PiRpcProcessExitException) {
        await Future<void>.delayed(Duration.zero);
      }
      if (!_ownsTurn(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
      if (turn is _PiQueuedPromptTurn && turn.queueState == _PiQueueState.cancelled) {
        _finish(sessionId: sessionId, state: state, turn: turn, failed: false, failure: null);
        return;
      }
      final connection = turn.connection;
      final connectionFailed =
          turn.promptDispatched && (error is TimeoutException || error is PiRpcProcessExitException);
      if (connectionFailed && connection != null) {
        _extensionUi.cancelForOwner(
          sessionId: sessionId,
          processGeneration: connection.generation,
        );
        if (error is TimeoutException) {
          await _processes.teardownConnection(connection: connection);
          if (!_ownsTurn(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
        }
      }
      if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
        turn.acceptance.completeError(error, stack);
      }
      if (!_ownsTurn(sessionId: sessionId, state: state, turn: turn, generation: generation)) return;
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
      if (connectionFailed && connection != null) {
        _finishConnectionTurns(
          sessionId: sessionId,
          state: state,
          processGeneration: connection.generation,
          failure: error,
        );
      } else {
        _finish(sessionId: sessionId, state: state, turn: turn, failed: true, failure: error);
      }
    }
  }

  void _moveInFlight({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
  }) {
    if (!identical(state.active, turn)) return;
    state
      ..active = null
      ..inFlight.add(turn);
    _startNext(sessionId: sessionId, state: state);
  }

  void _handleFrame(PiSessionProcessFrame processFrame) {
    final state = _sessions[processFrame.sessionId];
    if (state == null || !state.hasWork) return;
    state.active?.connection ??= PiSessionConnection(
      sessionId: processFrame.sessionId,
      generation: processFrame.generation,
    );
    final generationTurns = [
      for (final turn in state.turns)
        if (turn.connection?.generation == processFrame.generation) turn,
    ];
    if (generationTurns.isEmpty) return;
    switch (processFrame.frame) {
      case PiEventFrame(:final event):
        if (event is PiAgentStartEvent) {
          state.agentRunning = true;
          for (final turn in generationTurns) {
            if (!turn.promptDispatched) continue;
            turn
              ..agentStarted = true
              ..agentSettled = false
              ..settlementObservedBeforeAcceptance = false;
          }
        } else if (event is PiAgentSettledEvent) {
          state.agentRunning = false;
          for (final turn in generationTurns) {
            if (!turn.promptDispatched) continue;
            if (turn.responseSucceeded) {
              turn.agentSettled = true;
            } else {
              turn.settlementObservedBeforeAcceptance = true;
            }
          }
        }
        final now = _clock.now();
        final mappedStatus = _dispatcher.sessionStatusFor(event: event, now: now);
        final statusChanged =
            mappedStatus != null &&
            event is! PiAgentStartEvent &&
            event is! PiAgentSettledEvent &&
            state.status != mappedStatus;
        if (statusChanged) state.status = mappedStatus;
        final mappedEvents = _dispatcher.map(sessionId: processFrame.sessionId, event: event, now: now);
        for (final mapped in mappedEvents) {
          final serviceOwnsLifecycle =
              (event is PiAgentStartEvent || event is PiAgentSettledEvent) &&
              (mapped is BridgeSseSessionStatus || mapped is BridgeSseSessionIdle);
          if (!serviceOwnsLifecycle) _emit(mapped);
          if (mapped is! BridgeSseMessageUpdated) continue;
          final promptId = mapped.info["promptId"];
          if (promptId is! String) continue;
          final correlated = _turnForPrompt(state: state, promptId: promptId);
          if (correlated == null) continue;
          correlated.userMessageEmitted = true;
          if (correlated is _PiQueuedPromptTurn && correlated.queueState == _PiQueueState.visible) {
            _releaseQueuedPresentation(sessionId: processFrame.sessionId, state: state, turn: correlated);
          }
        }
        if (statusChanged) _emit(const BridgeSseProjectUpdated());
        if (event is PiAgentSettledEvent) {
          for (final turn in List<_PiTurn>.of(generationTurns)) {
            if (turn.promptDispatched && turn.responseSucceeded) {
              _finish(
                sessionId: processFrame.sessionId,
                state: state,
                turn: turn,
                failed: false,
                failure: null,
              );
            }
          }
        }
      case PiExtensionUiFrame(:final request):
        final commandTurn = _pendingCommandTurn(state: state, processGeneration: processFrame.generation);
        if (commandTurn != null && request is PiExtensionDialogRequest && !commandTurn.acceptance.isCompleted) {
          commandTurn.acceptance.complete();
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

  _PiTurn? _turnForPrompt({required _PiSessionTurnState state, required String promptId}) {
    for (final turn in state.turns) {
      if (turn.promptId == promptId) return turn;
    }
    return null;
  }

  _PiCommandTurn? _pendingCommandTurn({required _PiSessionTurnState state, required int processGeneration}) {
    for (final turn in state.turns.whereType<_PiCommandTurn>()) {
      if (turn.promptDispatched && turn.connection?.generation == processGeneration) return turn;
    }
    return null;
  }

  void _clearCompaction({required String sessionId}) {
    _dispatcher.clearCompaction(sessionId: sessionId).forEach(_emit);
  }

  void _handleExit(PiSessionProcessExit exit) {
    _extensionUi.cancelForOwner(sessionId: exit.sessionId, processGeneration: exit.generation);
    final state = _sessions[exit.sessionId];
    if (state == null) return;
    final affected = [
      for (final turn in state.turns)
        if (turn.connection?.generation == exit.generation) turn,
    ];
    if (affected.isEmpty) return;
    _clearCompaction(sessionId: exit.sessionId);
    state.agentRunning = false;
    final hasUncancelled = affected.any(
      (turn) => turn is! _PiQueuedPromptTurn || turn.queueState != _PiQueueState.cancelled,
    );
    if (hasUncancelled && exit.authUnavailable) {
      _emit(
        const BridgeSseTuiToastShow(
          title: "Pi login required",
          message: "Pi has no model available. Run Pi locally and use /login, then try again.",
          variant: "warning",
        ),
      );
    }
    final failure = PiRpcProcessExitException(exitCode: exit.exitCode);
    if (hasUncancelled) {
      Log.w("[pi] resident process exited during active turns for session id=${exit.sessionId}", failure);
    }
    for (final turn in affected) {
      final cancelled = turn is _PiQueuedPromptTurn && turn.queueState == _PiQueueState.cancelled;
      _finish(
        sessionId: exit.sessionId,
        state: state,
        turn: turn,
        failed: !cancelled,
        failure: cancelled ? null : failure,
      );
    }
  }

  void _finishConnectionTurns({
    required String sessionId,
    required _PiSessionTurnState state,
    required int processGeneration,
    required Object failure,
  }) {
    _clearCompaction(sessionId: sessionId);
    state.agentRunning = false;
    final affected = [
      for (final turn in state.turns)
        if (turn.connection?.generation == processGeneration) turn,
    ];
    for (final turn in affected) {
      final cancelled = turn is _PiQueuedPromptTurn && turn.queueState == _PiQueueState.cancelled;
      _finish(
        sessionId: sessionId,
        state: state,
        turn: turn,
        failed: !cancelled,
        failure: cancelled ? null : failure,
      );
    }
  }

  void _finish({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
    required bool failed,
    required Object? failure,
  }) {
    if (turn.settled || !identical(_sessions[sessionId], state)) return;
    final owned = identical(state.active, turn) || state.inFlight.contains(turn) || state.queue.contains(turn);
    if (!owned) return;
    turn.settled = true;
    if (turn.promptDispatched) {
      state.recordSettledPromptId(promptId: turn.promptId);
    }
    if (turn is _PiCommandTurn && !turn.acceptance.isCompleted && failed) {
      turn.acceptance.completeError(
        failure ?? StateError("Pi command failed before acceptance"),
        StackTrace.current,
      );
    }
    if (!failed && turn.promptDispatched && !turn.userMessageEmitted) {
      _emitMissingUserMessage(sessionId: sessionId, turn: turn);
    } else if (!turn.userMessageEmitted) {
      _dispatcher.cancelPrompt(sessionId: sessionId, promptId: turn.promptId);
    }
    if (identical(state.active, turn)) state.active = null;
    state
      ..inFlight.remove(turn)
      ..queue.remove(turn);
    if (turn is _PiQueuedPromptTurn) {
      _releaseQueuedPresentation(sessionId: sessionId, state: state, turn: turn);
    }
    if (failed) _emit(BridgeSseSessionError(sessionID: sessionId));
    unawaited(_clearPendingWhenPersisted(sessionId: sessionId, directory: state.directory));
    _startNext(sessionId: sessionId, state: state);
    if (state.hasWork) {
      if (state.status != const PluginSessionStatus.busy()) {
        state.status = const PluginSessionStatus.busy();
        _emit(
          BridgeSseSessionStatus(
            sessionID: sessionId,
            status: const shared.SessionStatus.busy().toJson(),
          ),
        );
        _emit(const BridgeSseProjectUpdated());
      }
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

  void _emitMissingUserMessage({required String sessionId, required _PiTurn turn}) {
    final now = _clock.now();
    final message = <String, Object?>{
      "role": "user",
      "content": <Object?>[
        if (turn.payload.message.isNotEmpty) {"type": "text", "text": turn.payload.message},
        ...turn.payload.images,
      ],
      "timestamp": now.millisecondsSinceEpoch,
    };
    final raw = <String, Object?>{"type": "message_end", "message": message};
    final mappedEvents = _dispatcher.map(
      sessionId: sessionId,
      event: PiMessageEndEvent(message: message, raw: raw),
      now: now,
    );
    mappedEvents.forEach(_emit);
    turn.userMessageEmitted = mappedEvents.any(
      (mapped) => mapped is BridgeSseMessageUpdated && mapped.info["promptId"] == turn.promptId,
    );
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

  Future<void> abort({required String sessionId}) {
    return _abort(sessionId: sessionId, processExitIsExpected: false);
  }

  Future<void> _abort({
    required String sessionId,
    required bool processExitIsExpected,
  }) async {
    final state = _sessions[sessionId];
    if (state == null) {
      await _processes.teardown(sessionId: sessionId);
      return;
    }
    state.generation++;
    state.idleGeneration++;
    final cancelled = state.turns.toList(growable: false);
    final hadQueuedPresentations = cancelled.any(
      (turn) => turn is _PiQueuedPromptTurn && turn.queueState == _PiQueueState.visible,
    );
    for (final turn in cancelled) {
      if (turn is _PiQueuedPromptTurn) turn.queueState = _PiQueueState.cancelled;
    }
    state
      ..active = null
      ..agentRunning = false
      ..inFlight.clear()
      ..queue.clear()
      ..status = const PluginSessionStatus.idle();
    for (final turn in cancelled) {
      _dispatcher.cancelPrompt(sessionId: sessionId, promptId: turn.promptId);
      if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
        turn.acceptance.completeError(PiTurnCancelledException(sessionId: sessionId), StackTrace.current);
      }
    }
    _clearCompaction(sessionId: sessionId);
    if (hadQueuedPresentations) _emitQueueUpdate(sessionId: sessionId, state: state);
    _extensionUi.cancelForOwner(sessionId: sessionId, processGeneration: null);
    final connection = cancelled.firstOrNull?.connection;
    try {
      final idleReap = state.idleReap;
      if (idleReap != null) await idleReap;
      if (connection != null) {
        switch (await _processes.abort(connection: connection)) {
          case PiSessionAbortAcknowledged():
            break;
          case PiSessionAbortProcessExited(:final innerError, :final innerStackTrace):
            if (!processExitIsExpected) {
              Log.w("[pi] abort command failed for session id=$sessionId", innerError, innerStackTrace);
            }
        }
      }
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
          if (entry.value.hasWork) entry.key,
      };
      if (activeSessionIds.isEmpty) return const <String>{};
      await Future.wait([
        for (final sessionId in activeSessionIds)
          _abort(sessionId: sessionId, processExitIsExpected: true),
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
      for (final turn in state.turns) {
        _dispatcher.cancelPrompt(sessionId: sessionId, promptId: turn.promptId);
        if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
          turn.acceptance.completeError(PiTurnCancelledException(sessionId: sessionId), StackTrace.current);
        }
      }
      state
        ..active = null
        ..agentRunning = false
        ..inFlight.clear()
        ..queue.clear();
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
    final idleTimeout = _resolveIdleTimeout();
    if (idleTimeout == null) return;
    unawaited(() async {
      await _clock.delay(duration: idleTimeout);
      if (_disposed ||
          !identical(_sessions[sessionId], state) ||
          state.hasWork ||
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
      _ownsTurn(sessionId: sessionId, state: state, turn: turn, generation: generation) &&
      (turn is! _PiQueuedPromptTurn || turn.queueState != _PiQueueState.cancelled);

  bool _ownsTurn({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiTurn turn,
    required int generation,
  }) =>
      !_disposed &&
      identical(_sessions[sessionId], state) &&
      identical(state.active, turn) &&
      state.generation == generation;

  void _releaseQueuedPresentation({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiQueuedPromptTurn turn,
  }) {
    if (turn.queueState != _PiQueueState.visible) return;
    turn.queueState = _PiQueueState.released;
    _emitQueueUpdate(sessionId: sessionId, state: state);
  }

  void _cancelQueuedPresentation({
    required String sessionId,
    required _PiSessionTurnState state,
    required _PiQueuedPromptTurn turn,
  }) {
    if (turn.queueState != _PiQueueState.visible) return;
    turn.queueState = _PiQueueState.cancelled;
    _emitQueueUpdate(sessionId: sessionId, state: state);
  }

  void _emitQueueUpdate({required String sessionId, required _PiSessionTurnState state}) {
    _emit(
      BridgeSseQueuedPromptsUpdated(
        sessionID: sessionId,
        prompts: queuedPrompts(sessionId: sessionId),
      ),
    );
  }

  void _syncWorkState() => _workState.set(
    _sessions.values.any((state) => state.hasWork) ? PluginWorkState.busy : PluginWorkState.idle,
  );

  void _emit(BridgeSseEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// [shutdownBudget] `null` means no deadline.
  Future<void> dispose({Duration? shutdownBudget = const Duration(seconds: 15)}) =>
      _disposeFuture ??= _dispose(shutdownBudget: shutdownBudget);

  Future<void> _dispose({required Duration? shutdownBudget}) async {
    _disposed = true;
    for (final entry in _sessions.entries) {
      final state = entry.value;
      state.generation++;
      state.idleGeneration++;
      for (final turn in state.turns) {
        _dispatcher.cancelPrompt(sessionId: entry.key, promptId: turn.promptId);
        if (turn is _PiCommandTurn && !turn.acceptance.isCompleted) {
          turn.acceptance.completeError(const PiRpcDisposedException(), StackTrace.current);
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
