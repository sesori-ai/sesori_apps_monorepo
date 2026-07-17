import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../acp_protocol.dart";
import "../dispatchers/acp_turn_configuration_dispatcher.dart";
import "../dispatchers/acp_turn_event_dispatcher.dart";
import "../repositories/acp_session_repository.dart";
import "../trackers/acp_command_turn_tracker.dart";
import "../trackers/acp_session_directory_tracker.dart";
import "../trackers/acp_session_residency_tracker.dart";
import "../trackers/acp_turn_queue_tracker.dart";
import "acp_connection_service.dart";

/// Owns ACP turn serialization and the complete command-turn workflow.
class AcpTurnService {
  AcpTurnService({
    required this.pluginId,
    required this.connectionService,
    required this.directoryTracker,
    required this.residencyTracker,
    required this.queueTracker,
    required this.commandTurnTracker,
    required this.eventDispatcher,
    required this.turnConfigurationDispatcher,
    required Duration commandFastFailWindow,
  }) : _commandFastFailWindow = commandFastFailWindow;

  final String pluginId;
  final AcpConnectionService connectionService;
  final AcpSessionDirectoryTracker directoryTracker;
  final AcpSessionResidencyTracker residencyTracker;
  final AcpTurnQueueTracker queueTracker;
  final AcpCommandTurnTracker commandTurnTracker;
  final AcpTurnEventDispatcher eventDispatcher;
  final AcpTurnConfigurationDispatcher turnConfigurationDispatcher;
  final Duration _commandFastFailWindow;
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => eventDispatcher.events;

  Map<String, PluginSessionStatus> get sessionStatuses => queueTracker.statuses;

  String? get activeTurnSessionId => queueTracker.resolveActiveSession();

  int pendingTurnCount(String sessionId) => queueTracker.pendingTurnCount(sessionId);

  bool isRunning(String sessionId) => queueTracker.isRunning(sessionId);

  void resetConnection() {
    residencyTracker.resetConnection();
    turnConfigurationDispatcher.reset();
  }

  void registerSession({required String sessionId, required bool resident}) {
    queueTracker.setStatus(
      sessionId: sessionId,
      status: const PluginSessionStatus.idle(),
    );
    if (resident) residencyTracker.markResident(sessionId);
  }

  void enqueuePrompt({
    required String sessionId,
    required List<AcpContentBlock> blocks,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) {
    _enqueueTurn(
      sessionId: sessionId,
      blocks: blocks,
      model: model,
      variant: variant,
      agent: agent,
      commandTurnId: null,
    );
  }

  Future<PluginCommandDispatch> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    final normalizedCommand = command.startsWith("/") ? command.substring(1) : command;
    final registration = commandTurnTracker.register(
      sessionId: sessionId,
      invocationId: invocationId,
      name: normalizedCommand,
      arguments: arguments,
    );
    final body = arguments.isEmpty ? "/$normalizedCommand" : "/$normalizedCommand $arguments";
    try {
      final queuedBehindExistingWork = _enqueueTurn(
        sessionId: sessionId,
        blocks: [AcpTextContentBlock(text: body)],
        model: model,
        variant: variant,
        agent: agent,
        commandTurnId: registration.turnId,
      );
      if (queuedBehindExistingWork) {
        commandTurnTracker.accept(registration.turnId);
      }
    } on Object catch (error, stackTrace) {
      commandTurnTracker.reject(
        turnId: registration.turnId,
        error: error,
        stackTrace: stackTrace,
      );
    }
    return registration.accepted;
  }

  Future<void> abortSession({required String sessionId}) async {
    queueTracker.abortSession(sessionId);
    for (final turnId in commandTurnTracker.turnIdsForSession(
      sessionId: sessionId,
      onlyUnaccepted: true,
    )) {
      commandTurnTracker.reject(
        turnId: turnId,
        error: StateError("ACP command was aborted before acceptance"),
        stackTrace: StackTrace.current,
      );
    }
    connectionService.current?.repository.cancelSession(sessionId: sessionId);
  }

  void forgetSession(String sessionId) {
    for (final turnId in commandTurnTracker.turnIdsForSession(
      sessionId: sessionId,
      onlyUnaccepted: false,
    )) {
      commandTurnTracker.reject(
        turnId: turnId,
        error: StateError("ACP session was deleted before command dispatch"),
        stackTrace: StackTrace.current,
      );
    }
    commandTurnTracker.forgetSession(sessionId);
    queueTracker.forgetSession(sessionId);
    residencyTracker.forgetSession(sessionId);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final state in queueTracker.states) {
      state.generation++;
    }
    for (final turnId in commandTurnTracker.turnIds) {
      commandTurnTracker.reject(
        turnId: turnId,
        error: StateError("ACP plugin disposed before command dispatch"),
        stackTrace: StackTrace.current,
      );
    }
    await eventDispatcher.dispose();
  }

  bool _enqueueTurn({
    required String sessionId,
    required List<AcpContentBlock> blocks,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
    required String? commandTurnId,
  }) {
    if (_disposed) throw StateError("AcpTurnService is disposed");
    if (blocks.isEmpty) return false;

    final state = queueTracker.stateForEnqueue(sessionId);
    final queuedBehindExistingWork = state.pending > 0;
    state.pending++;
    if (state.pending == 1) {
      queueTracker.setStatus(
        sessionId: sessionId,
        status: const PluginSessionStatus.busy(),
      );
      eventDispatcher.emit(
        BridgeSseSessionStatus(
          sessionID: sessionId,
          status: const shared.SessionStatus.busy().toJson(),
        ),
      );
    }
    final expectedGeneration = state.generation;
    state.tail = state.tail.then(
      (_) => _runTurn(
        sessionId: sessionId,
        state: state,
        expectedGeneration: expectedGeneration,
        blocks: blocks,
        model: model,
        variant: variant,
        agent: agent,
        commandTurnId: commandTurnId,
      ),
    );
    return queuedBehindExistingWork;
  }

  Future<void> _runTurn({
    required String sessionId,
    required AcpSessionTurnState state,
    required int expectedGeneration,
    required List<AcpContentBlock> blocks,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
    required String? commandTurnId,
  }) async {
    if (_turnWasAborted(
      sessionId: sessionId,
      state: state,
      expectedGeneration: expectedGeneration,
      commandTurnId: commandTurnId,
      message: "ACP command was aborted before dispatch",
    )) {
      return;
    }

    final AcpConnection connection;
    try {
      connection = await connectionService.ensureConnected();
    } on Object catch (error, stackTrace) {
      if (_turnWasAborted(
        sessionId: sessionId,
        state: state,
        expectedGeneration: expectedGeneration,
        commandTurnId: commandTurnId,
        message: "ACP command was aborted during reconnect",
        stackTrace: stackTrace,
      )) {
        Log.d("[$pluginId] queued turn on $sessionId aborted during reconnect: $error");
        return;
      }
      final commandAccepted = _rejectBeforeDispatch(
        commandTurnId: commandTurnId,
        error: error,
        stackTrace: stackTrace,
      );
      if (commandTurnId == null || commandAccepted) {
        Log.w(
          "[$pluginId] could not reach the agent for a queued turn on $sessionId",
          error,
          stackTrace,
        );
      }
      _finishTurn(
        sessionId: sessionId,
        state: state,
        failed: commandTurnId == null || commandAccepted,
        refused: false,
      );
      return;
    }

    if (_turnWasAborted(
      sessionId: sessionId,
      state: state,
      expectedGeneration: expectedGeneration,
      commandTurnId: commandTurnId,
      message: "ACP command was aborted before resume",
    )) {
      return;
    }

    try {
      await _ensureResident(
        connection: connection,
        sessionId: sessionId,
        failOnError: commandTurnId != null,
      );
    } on Object catch (error, stackTrace) {
      final commandAccepted = _rejectBeforeDispatch(
        commandTurnId: commandTurnId,
        error: error,
        stackTrace: stackTrace,
      );
      if (commandAccepted) {
        Log.w(
          "[$pluginId] could not resume queued command session $sessionId",
          error,
          stackTrace,
        );
      }
      _finishTurn(
        sessionId: sessionId,
        state: state,
        failed: commandTurnId == null || commandAccepted,
        refused: false,
      );
      return;
    }

    if (_turnWasAborted(
      sessionId: sessionId,
      state: state,
      expectedGeneration: expectedGeneration,
      commandTurnId: commandTurnId,
      message: "ACP command was aborted during resume",
    )) {
      return;
    }

    try {
      await turnConfigurationDispatcher.apply(
        repository: connection.repository,
        sessionId: sessionId,
        model: model,
        variant: variant,
        agent: agent,
        failOnError: commandTurnId != null,
      );
    } on Object catch (error, stackTrace) {
      if (commandTurnId != null) {
        final commandAccepted = _rejectBeforeDispatch(
          commandTurnId: commandTurnId,
          error: error,
          stackTrace: stackTrace,
        );
        if (commandAccepted) {
          Log.w(
            "[$pluginId] queued command configuration for $sessionId failed",
            error,
            stackTrace,
          );
        }
        _finishTurn(
          sessionId: sessionId,
          state: state,
          failed: commandAccepted,
          refused: false,
        );
        return;
      }
      Log.w(
        "[$pluginId] turn configuration for $sessionId failed; prompting with current settings",
        error,
        stackTrace,
      );
    }

    if (_turnWasAborted(
      sessionId: sessionId,
      state: state,
      expectedGeneration: expectedGeneration,
      commandTurnId: commandTurnId,
      message: "ACP command was aborted during turn configuration",
    )) {
      return;
    }

    eventDispatcher.beginTurn(sessionId: sessionId);
    queueTracker.beginInFlight(sessionId);
    try {
      if (commandTurnId != null) _startCommand(commandTurnId);
      final request = connection.repository.prompt(
        sessionId: sessionId,
        blocks: blocks,
      );
      if (commandTurnId != null) {
        await _awaitCommandAcceptance(
          turnId: commandTurnId,
          request: request,
        );
      }
      final result = await request;
      if (commandTurnId != null) commandTurnTracker.complete(commandTurnId);
      _finishTurn(
        sessionId: sessionId,
        state: state,
        failed: false,
        refused: result.stopReason == AcpStopReason.refusal,
      );
    } on Object catch (error, stackTrace) {
      final commandAccepted = commandTurnId != null && commandTurnTracker.isAccepted(commandTurnId);
      if (commandTurnId != null && !commandAccepted) {
        commandTurnTracker.reject(
          turnId: commandTurnId,
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (commandTurnId == null || commandAccepted) {
        Log.w(
          "[$pluginId] session/prompt for $sessionId failed after dispatch",
          error,
          stackTrace,
        );
      }
      if (commandTurnId != null) commandTurnTracker.complete(commandTurnId);
      _finishTurn(
        sessionId: sessionId,
        state: state,
        failed: commandTurnId == null || commandAccepted,
        refused: false,
      );
    }
  }

  Future<void> _ensureResident({
    required AcpConnection connection,
    required String sessionId,
    required bool failOnError,
  }) async {
    if (residencyTracker.isResident(sessionId)) return;
    final capabilities = connection.initializeResult.agentCapabilities;
    final loadSupported = capabilities.loadSession;
    final resumeSupported = capabilities.resumeSession;
    if (!loadSupported && !resumeSupported) {
      residencyTracker.markResident(sessionId);
      return;
    }
    if (!directoryTracker.containsSession(sessionId) && capabilities.listSessions) {
      final location = await connection.repository.findSession(
        sessionId: sessionId,
        scanDirectories: directoryTracker.scanDirectories,
      );
      if (location != null) {
        final directory = directoryTracker.recordAuthoritative(
          sessionId: sessionId,
          directory: location.directory,
        );
        eventDispatcher.recordDiscoveredSession(
          sessionId: sessionId,
          projectId: directory,
          title: location.info.title,
          updatedMs: location.info.updatedAtMs,
        );
      }
    }
    if (!loadSupported) {
      await _resumeResident(
        repository: connection.repository,
        sessionId: sessionId,
        failOnError: failOnError,
      );
      return;
    }

    residencyTracker.beginReplaySuppression(sessionId);
    try {
      final result = await connection.repository.loadSession(
        sessionId: sessionId,
        directory: directoryTracker.directoryFor(sessionId),
      );
      turnConfigurationDispatcher.captureSessionConfig(
        result,
        sessionId: sessionId,
        fromNewSession: false,
      );
      await _drainReplay(sessionId);
      residencyTracker.markResident(sessionId);
    } on AcpRpcException catch (error, stackTrace) {
      if (failOnError) Error.throwWithStackTrace(error, stackTrace);
      if (error.code == -32601 || error.code == -32602) {
        Log.w(
          "[$pluginId] session/load unsupported (code ${error.code}); proceeding without resume-load",
          error,
          stackTrace,
        );
        residencyTracker.markResident(sessionId);
      } else {
        Log.w(
          "[$pluginId] resume-load of $sessionId failed; will retry on next turn",
          error,
          stackTrace,
        );
      }
    } on Object catch (error, stackTrace) {
      if (failOnError) Error.throwWithStackTrace(error, stackTrace);
      Log.w(
        "[$pluginId] resume-load of $sessionId failed; will retry on next turn",
        error,
        stackTrace,
      );
    } finally {
      residencyTracker.endReplaySuppression(sessionId);
    }
  }

  Future<void> _resumeResident({
    required AcpSessionRepository repository,
    required String sessionId,
    required bool failOnError,
  }) async {
    try {
      final result = await repository.resumeSession(
        sessionId: sessionId,
        directory: directoryTracker.directoryFor(sessionId),
      );
      turnConfigurationDispatcher.captureSessionConfig(
        result,
        sessionId: sessionId,
        fromNewSession: false,
      );
      residencyTracker.markResident(sessionId);
    } on AcpRpcException catch (error, stackTrace) {
      if (failOnError) Error.throwWithStackTrace(error, stackTrace);
      if (error.code == -32601 || error.code == -32602) {
        Log.w(
          "[$pluginId] session/resume unsupported (code ${error.code}); proceeding without resume",
          error,
          stackTrace,
        );
        residencyTracker.markResident(sessionId);
      } else {
        Log.w(
          "[$pluginId] session/resume of $sessionId failed; will retry on next turn",
          error,
          stackTrace,
        );
      }
    } on Object catch (error, stackTrace) {
      if (failOnError) Error.throwWithStackTrace(error, stackTrace);
      Log.w(
        "[$pluginId] session/resume of $sessionId failed; will retry on next turn",
        error,
        stackTrace,
      );
    }
  }

  Future<void> _drainReplay(
    String sessionId, {
    Duration quiet = const Duration(milliseconds: 250),
    Duration max = const Duration(seconds: 6),
  }) async {
    var elapsed = Duration.zero;
    var last = -1;
    while (elapsed < max) {
      final snapshot = residencyTracker.replayCount(sessionId);
      if (snapshot == last) return;
      last = snapshot;
      await Future<void>.delayed(quiet);
      elapsed += quiet;
    }
  }

  bool _turnWasAborted({
    required String sessionId,
    required AcpSessionTurnState state,
    required int expectedGeneration,
    required String? commandTurnId,
    required String message,
    StackTrace? stackTrace,
  }) {
    if (state.generation == expectedGeneration) return false;
    _rejectBeforeDispatch(
      commandTurnId: commandTurnId,
      error: StateError(message),
      stackTrace: stackTrace ?? StackTrace.current,
    );
    _finishTurn(
      sessionId: sessionId,
      state: state,
      failed: false,
      refused: false,
    );
    return true;
  }

  void _startCommand(String turnId) {
    eventDispatcher.stageCommandEnvelope(turnId: turnId);
  }

  Future<void> _awaitCommandAcceptance<T>({
    required String turnId,
    required Future<T> request,
  }) async {
    final state = commandTurnTracker.requireState(turnId);
    try {
      await request
          .then<void>((_) {})
          .timeout(
            _commandFastFailWindow,
            onTimeout: () {},
          );
    } on Object catch (error, stackTrace) {
      if (!commandTurnTracker.isAccepted(turnId)) {
        commandTurnTracker.reject(
          turnId: turnId,
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
    if (!commandTurnTracker.containsState(turnId: turnId, state: state)) {
      throw StateError("ACP command was aborted before acceptance");
    }
    eventDispatcher.flushCommand(turnId);
  }

  bool _rejectBeforeDispatch({
    required String? commandTurnId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (commandTurnId == null) return false;
    final commandAccepted = commandTurnTracker.isAccepted(commandTurnId);
    commandTurnTracker.reject(
      turnId: commandTurnId,
      error: error,
      stackTrace: stackTrace,
    );
    return commandAccepted;
  }

  void _finishTurn({
    required String sessionId,
    required AcpSessionTurnState state,
    required bool failed,
    required bool refused,
  }) {
    queueTracker.endInFlight(sessionId);
    if (state.pending > 0) state.pending--;
    if (!queueTracker.ownsState(sessionId: sessionId, state: state)) return;
    if (state.pending == 0) {
      queueTracker.setStatus(
        sessionId: sessionId,
        status: const PluginSessionStatus.idle(),
      );
      eventDispatcher.emit(BridgeSseSessionIdle(sessionID: sessionId));
    }
    if (failed || refused) {
      eventDispatcher.emit(BridgeSseSessionError(sessionID: sessionId));
    }
  }
}
