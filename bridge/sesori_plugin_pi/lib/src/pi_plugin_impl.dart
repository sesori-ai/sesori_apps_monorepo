import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/pi_process_factory.dart";
import "api/pi_session_storage_api.dart";
import "models/pi_notification_type.dart";
import "models/pi_thinking_level.dart";
import "pi_identity.dart";
import "repositories/mappers/pi_history_mapper.dart";
import "repositories/pi_backend_catalog_repository.dart";
import "repositories/pi_session_catalog_repository.dart";
import "repositories/pi_session_process_repository.dart";
import "services/pi_catalog_service.dart";
import "services/pi_event_dispatcher.dart";
import "services/pi_extension_ui_service.dart";
import "services/pi_session_service.dart";
import "trackers/pi_catalog_tracker.dart";
import "trackers/pi_extension_ui_tracker.dart";
import "trackers/pi_message_identity_tracker.dart";
import "trackers/pi_tool_tracker.dart";

final class PiPlugin._({
  required final PiSessionCatalogRepository _catalogRepository,
  required final PiSessionProcessRepository _processRepository,
  required final PiSessionService _sessionService,
  required final PiCatalogService _catalogService,
  required final PiExtensionUiService _extensionUiService,
  required final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer,
  required final ServerClock _clock,
  required final String _launchDirectory,
}) extends BridgeDerivedProjectsPluginApi implements PersistedSessionCleanupApi {
  this {
    _subscriptions.add(_sessionService.events.listen(_eventBuffer.add));
    _subscriptions.add(_extensionUiService.events.listen(_handleExtensionEvent));
  }

  factory({
    required String binaryPath,
    required Map<String, String> storageEnvironment,
    required Map<String, String> processEnvironment,
    required PiProcessFactory processFactory,
    required CommandExecutor commandExecutor,
    required ServerClock clock,
    required String launchDirectory,
    required Duration startupExitTimeout,
    required Duration historyRpcTimeout,
    required Duration catalogTimeout,
    required Duration healthTimeout,
    required Duration? Function() resolveIdleTimeout,
    required Duration editorTimeout,
  }) {
    final storage = PiSessionStorageApi(environment: storageEnvironment);
    final catalogRepository = PiSessionCatalogRepository(storageApi: storage);
    final identities = PiMessageIdentityTracker(pluginId: pluginId);
    final history = PiHistoryMapper(pluginId: pluginId);
    final processRepository = PiSessionProcessRepository(
      storageApi: storage,
      historyStorageApi: PiSessionHistoryStorageApi(storageApi: storage),
      binaryPath: binaryPath,
      environment: processEnvironment,
      processFactory: processFactory,
      historyMapper: history,
      identityTracker: identities,
      startupExitTimeout: startupExitTimeout,
      historyRpcTimeout: historyRpcTimeout,
      // Pi's abort response waits for full agent idleness, which can include
      // an already queued steering continuation. Bound that acknowledgement
      // tightly so Stop can force process replacement instead of stalling.
      abortRpcTimeout: const Duration(seconds: 1),
      // Pi can run model-backed automatic compaction before acknowledging a
      // prompt, so prompt preflight needs the same generous bound as a turn.
      promptRpcTimeout: const Duration(minutes: 30),
    );
    final extensionUiService = PiExtensionUiService(
      catalogRepository: catalogRepository,
      processRepository: processRepository,
      tracker: PiExtensionUiTracker(),
      editorTimeout: editorTimeout,
    );
    final sessionService = PiSessionService(
      processRepository: processRepository,
      catalogRepository: catalogRepository,
      eventDispatcher: PiEventDispatcher(
        historyMapper: history,
        identityTracker: identities,
        toolTracker: PiToolTracker(),
      ),
      extensionUiService: extensionUiService,
      clock: clock,
      resolveIdleTimeout: resolveIdleTimeout,
    );
    final catalogService = PiCatalogService(
      repository: PiBackendCatalogRepository(
        binaryPath: binaryPath,
        environment: processEnvironment,
        processFactory: processFactory,
        commandExecutor: commandExecutor,
        healthTimeout: healthTimeout,
      ),
      tracker: PiCatalogTracker(),
      totalTimeout: catalogTimeout,
    );
    return PiPlugin._(
      catalogRepository: catalogRepository,
      processRepository: processRepository,
      sessionService: sessionService,
      catalogService: catalogService,
      extensionUiService: extensionUiService,
      eventBuffer: BufferedUntilFirstListener<BridgeSseEvent>(),
      clock: clock,
      launchDirectory: normalizeProjectDirectory(directory: launchDirectory),
    );
  }

  static const String pluginId = PiPluginIdentity.id;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void>? _disposeFuture;
  bool _disposed = false;

  @override
  String get id => pluginId;

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  Stream<PluginWorkState> get workState => _sessionService.workState;

  PluginWorkState get currentWorkState => _sessionService.currentWorkState;

  @override
  String get launchDirectory => _launchDirectory;

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) =>
      _catalogRepository.primeSessionDirectory(sessionId: sessionId, directory: directory);

  @override
  Future<List<PluginSession>> getSessions({required String projectId, required int? start, required int? limit}) =>
      _catalogRepository.getSessions(projectId: projectId, start: start, limit: limit);

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) =>
      _catalogRepository.listAllSessions(knownDirectories: knownDirectories);

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) =>
      _catalogService.getCommands(projectId: projectId ?? _launchDirectory);

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _catalogService.getSessionOptions(projectId: projectId, discoveryMode: discoveryMode);

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final normalized = normalizeProjectDirectory(directory: directory);
    await _validateSelection(
      projectId: normalized,
      variant: variant,
      agent: agent,
      model: model,
      operation: "createSession",
      staleOptions: false,
    );
    final sessionId = await _sessionService.prepareNewSession(
      directory: normalized,
      parentSessionId: parentSessionId,
    );
    final now = _clock.now().millisecondsSinceEpoch;
    final session = PluginSession(
      id: sessionId,
      projectID: normalized,
      directory: normalized,
      parentID: parentSessionId,
      title: null,
      time: PluginSessionTime(created: now, updated: now, archived: null),
    );
    _catalogRepository.recordPendingSession(
      sessionId: sessionId,
      directory: normalized,
      parentSessionId: parentSessionId,
    );
    _eventBuffer.add(BridgeSseSessionCreated(info: session.toJson()));
    if (parts.isNotEmpty) {
      try {
        await _sessionService.sendInitialPrompt(
          sessionId: sessionId,
          // createSession carries no client prompt id; a fresh random id keys
          // this initial turn without ever colliding with client-supplied ids.
          promptId: _processRepository.generateSessionId(),
          directory: normalized,
          parts: parts,
          userVisibleText: userVisibleText,
          variant: variant,
          model: model,
        );
      } on Object {
        await _sessionService.forgetSession(sessionId: sessionId);
        _catalogRepository.forgetSession(sessionId: sessionId);
        _eventBuffer.add(BridgeSseSessionDeleted(info: session.toJson()));
        rethrow;
      }
    }
    return session;
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    final session = await _requiredSession(sessionId: sessionId, operation: "renameSession");
    try {
      await _processRepository.renameSession(
        sessionId: sessionId,
        title: title,
        knownDirectories: {session.directory},
      );
    } on PluginOperationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException("renameSession", message: "Pi session rename failed.", cause: error),
        stackTrace,
      );
    }
    final renamed = session.copyWith(title: title);
    _eventBuffer.add(BridgeSseSessionUpdated(info: renamed.toJson(), titleChanged: true));
    return renamed;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final root = await _requiredSession(sessionId: sessionId, operation: "deleteSession");
    try {
      await _sessionService.deleteSession(root: root);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException("deleteSession", message: "Pi session deletion failed.", cause: error),
        stackTrace,
      );
    }
    _eventBuffer.add(BridgeSseSessionDeleted(info: root.toJson()));
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) =>
      // Startup-retry cleanup has no directory context; the storage API falls
      // back to scanning Pi's known session directories and simply misses
      // files whose cwd is no longer discoverable (accepted low-damage leak).
      _processRepository.deletePersistedSession(sessionId: backendSessionId, directory: null);

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) =>
      _catalogRepository.getChildSessions(sessionId: sessionId);

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => _sessionService.sessionStatuses;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final session = await _requiredSession(sessionId: sessionId, operation: "getSessionMessages");
    if (session.time == null) return const [];
    try {
      final history = await _processRepository.loadHistory(
        sessionId: sessionId,
        knownDirectories: {session.directory},
      );
      return _sessionService.withLiveMessages(sessionId: sessionId, history: history);
    } on PluginOperationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "getSessionMessages",
          message: "Pi session history could not be loaded.",
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (parts.isEmpty) {
      throw const PluginOperationException("sendPrompt", statusCode: 400, message: "Prompt parts are required.");
    }
    final session = await _requiredSession(sessionId: sessionId, operation: "sendPrompt");
    await _validateSelection(
      projectId: session.directory,
      variant: variant,
      agent: agent,
      model: model,
      operation: "sendPrompt",
      staleOptions: true,
    );
    await _sessionService.sendPrompt(
      sessionId: sessionId,
      promptId: promptId,
      directory: session.directory,
      parts: parts,
      userVisibleText: parts.whereType<PluginPromptPartText>().map((part) => part.text).join(),
      variant: variant,
      model: model,
    );
  }

  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async =>
      _sessionService.queuedPrompts(sessionId: sessionId);

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async =>
      _sessionService.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final session = await _requiredSession(sessionId: sessionId, operation: "sendCommand");
    await _validateSelection(
      projectId: session.directory,
      variant: variant,
      agent: agent,
      model: model,
      operation: "sendCommand",
      staleOptions: true,
    );
    final options = await _catalogService.requireOptions(projectId: session.directory);
    if (command.trim() != command || command.isEmpty) {
      throw const PluginOperationException("sendCommand", statusCode: 400, message: "Invalid Pi command.");
    }
    final catalogCommand = options.commands.where((candidate) => candidate.name == command).firstOrNull;
    if (catalogCommand == null) {
      throw const PluginStaleOptionsException(
        "sendCommand",
        message: "Pi no longer offers this command.",
      );
    }
    try {
      final dispatch = _catalogService.isNativeCompactionCommand(command: catalogCommand)
          ? _sessionService.compact(
              sessionId: sessionId,
              promptId: promptId,
              directory: session.directory,
              command: command,
              arguments: arguments,
              userVisibleArguments: userVisibleArguments,
              variant: variant,
              model: model,
            )
          : _sessionService.sendCommand(
              sessionId: sessionId,
              promptId: promptId,
              directory: session.directory,
              command: command,
              arguments: arguments,
              userVisibleArguments: userVisibleArguments,
              variant: variant,
              model: model,
            );
      await dispatch;
    } on PluginOperationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException("sendCommand", message: "Pi did not accept the command.", cause: error),
        stackTrace,
      );
    }
  }

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async {
    await _sessionService.abort(sessionId: sessionId);
    return const PluginAbortAccepted(workKept: false);
  }

  Future<Set<String>> interruptActiveWork({required Duration budget}) =>
      _sessionService.interruptActiveWork(budget: budget);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async =>
      (await _catalogService.requireOptions(projectId: projectId)).agents;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async =>
      _extensionUiService.getPendingQuestions(sessionId: sessionId);

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => const [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async =>
      _extensionUiService.getProjectQuestions(projectId: normalizeProjectDirectory(directory: projectId));

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async => _extensionUiService.replyToQuestion(
    questionId: questionId,
    sessionId: sessionId,
    answers: answers,
  );

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async =>
      _extensionUiService.rejectQuestion(questionId: questionId, sessionId: sessionId);

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => Future.error(
    const PluginOperationException.notFound("replyToPermission", message: "Permission not found."),
  );

  @override
  Future<bool> healthCheck() => _disposed ? Future.value(false) : _catalogService.healthCheck();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      (await _catalogService.requireOptions(projectId: projectId)).providers;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => _sessionService.getActiveSessionsSummary();

  Future<void> dispose() => _disposeFuture ??= _dispose(shutdownBudget: Duration.zero);

  /// [shutdownBudget] `null` means the caller imposes no deadline.
  Future<void> shutdown({required Duration? shutdownBudget}) =>
      _disposeFuture ??= _dispose(shutdownBudget: shutdownBudget);

  Future<void> _dispose({required Duration? shutdownBudget}) async {
    _disposed = true;
    Object? firstError;
    StackTrace? firstStack;
    Future<void> capture(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } on Object catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    await capture(() => _sessionService.dispose(shutdownBudget: shutdownBudget));
    for (final subscription in _subscriptions) {
      await capture(subscription.cancel);
    }
    await capture(_eventBuffer.close);
    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStack!);
  }

  PluginOperationException _unsupportedSelection({
    required String operation,
    required String message,
    required bool staleOptions,
  }) => staleOptions
      ? PluginStaleOptionsException(operation, message: message)
      : PluginOperationException(operation, statusCode: 400, message: message);

  Future<void> _validateSelection({
    required String projectId,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required String operation,
    required bool staleOptions,
  }) async {
    if (agent != null && agent != "pi") {
      throw _unsupportedSelection(operation: operation, message: "Unsupported Pi agent.", staleOptions: staleOptions);
    }
    if (variant != null && PiThinkingLevel.tryParse(value: variant.id) == null) {
      throw _unsupportedSelection(
        operation: operation,
        message: "Unsupported Pi thinking level.",
        staleOptions: staleOptions,
      );
    }
    if (model == null) return;
    final options = await _catalogService.requireOptions(projectId: projectId);
    final provider = options.providers.providers.where((candidate) => candidate.id == model.providerID).firstOrNull;
    if (provider == null || !provider.models.any((candidate) => candidate.id == model.modelID)) {
      throw _unsupportedSelection(operation: operation, message: "Unsupported Pi model.", staleOptions: staleOptions);
    }
    if (variant != null) {
      final selected = provider.models.firstWhere((candidate) => candidate.id == model.modelID);
      if (!selected.variants.contains(variant.id)) {
        throw _unsupportedSelection(
          operation: operation,
          message: "Unsupported Pi thinking level.",
          staleOptions: staleOptions,
        );
      }
    }
  }

  Future<PluginSession> _requiredSession({required String sessionId, required String operation}) async {
    final session = await _catalogRepository.findSessionById(sessionId: sessionId);
    if (session == null) throw PluginOperationException.notFound(operation, message: "Pi session was not found.");
    return session;
  }

  void _handleExtensionEvent(PiExtensionUiEvent event) {
    _eventBuffer.add(
      switch (event) {
        PiExtensionUiQuestionAsked(:final question) => BridgeSseQuestionAsked(
          id: question.id,
          sessionID: question.sessionID,
          displaySessionId: question.displaySessionId,
          questions: question.questions,
        ),
        PiExtensionUiQuestionReplied(:final requestId, :final ownerSessionId, :final displaySessionId) =>
          BridgeSseQuestionReplied(
            requestID: requestId,
            sessionID: ownerSessionId,
            displaySessionId: displaySessionId,
          ),
        PiExtensionUiQuestionRejected(:final requestId, :final ownerSessionId, :final displaySessionId) =>
          BridgeSseQuestionRejected(
            requestID: requestId,
            sessionID: ownerSessionId,
            displaySessionId: displaySessionId,
          ),
        PiExtensionUiToast(:final sessionId, :final title, :final message, :final variant) => BridgeSseTuiToastShow(
          sessionID: sessionId,
          title: title,
          message: message,
          variant: switch (variant) {
            PiNotificationType.info => "info",
            PiNotificationType.warning => "warning",
            PiNotificationType.error => "error",
          },
        ),
      },
    );
    if (event is PiExtensionUiQuestionAsked ||
        event is PiExtensionUiQuestionReplied ||
        event is PiExtensionUiQuestionRejected) {
      _eventBuffer.add(const BridgeSseProjectUpdated());
    }
  }
}
