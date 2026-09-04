import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_config_reader.dart";
import "../codex_metadata_repository.dart";
import "../models/codex_collaboration_mode.dart";
import "../models/codex_replay_tool_disposition.dart";
import "../repositories/codex_catalog_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/codex_model_repository.dart";
import "../repositories/codex_skill_repository.dart";
import "../repositories/codex_sub_agent_tracker.dart";
import "../repositories/codex_thread_repository.dart";
import "../repositories/codex_tool_outcome_repository.dart";
import "../repositories/mappers/codex_session_mapper.dart";
import "../repositories/models/codex_session_record.dart";
import "../repositories/models/codex_thread_record.dart";

final class const CodexSessionMessageRead._({
  required final CodexPreparedMessageRead _messages,
  required final Map<String, PluginToolStatus> _structuredToolStatusByCallId,
  required final CodexConfigDefaults _config,
});

final class const CodexSubAgentThreadAnnouncement({
  required final CodexThreadRecord child,
  required final List<BridgeSseEvent> events,
});

/// Layer-3 coordination for the migrated Codex session operations.
class CodexSessionService({
  required final CodexCatalogRepository _catalogRepository,
  required final CodexMessageRepository _messageRepository,
  required final CodexMetadataRepository _metadataRepository,
  required final CodexToolOutcomeRepository _toolOutcomeRepository,
  required final CodexSubAgentTracker _subAgentTracker,
  required final CodexSessionMapper _sessionMapper,
  required final String _launchDirectory,
}) {
  static const String compactionCommandName = "compact";

  static final PluginCommand _compactionCommand = PluginCommand.compaction(name: compactionCommandName);

  CodexThreadRepository? _threadRepository;
  CodexModelRepository? _modelRepository;
  CodexSkillRepository? _skillRepository;
  final Set<String> _loadedThreads = {};
  final Map<String, String> _threadModels = {};

  void attachAppServerRepositories({
    required CodexThreadRepository threadRepository,
    required CodexModelRepository modelRepository,
    required CodexSkillRepository skillRepository,
  }) {
    _threadRepository = threadRepository;
    _modelRepository = modelRepository;
    _skillRepository = skillRepository;
  }

  void detachAppServerRepositories() {
    _threadRepository = null;
    _modelRepository = null;
    _skillRepository = null;
    _loadedThreads.clear();
    _threadModels.clear();
    _subAgentTracker.clear();
  }

  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) =>
      _catalogRepository.listAllSessions(knownDirectories: knownDirectories);

  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) => _catalogRepository.getSessions(
    projectId: projectId,
    start: start,
    limit: limit,
  );

  /// Persisted children of [sessionId] plus the live children this connection
  /// learned that Codex has not flushed to a rollout yet.
  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    final persisted = await _catalogRepository.getChildSessions(sessionId: sessionId);
    final persistedIds = {for (final session in persisted) session.id};
    return [
      ...persisted,
      for (final child in _subAgentTracker.childrenOf(parentId: sessionId))
        if (!persistedIds.contains(child.id))
          _sessionMapper.mapThread(
            record: child,
            fallbackDirectory: _launchDirectory,
            parentSessionId: child.parentId,
          ),
    ];
  }

  /// Resolves and records a child named by `subAgentActivity started`, then
  /// maps its ordered creation/status events. A repeated activity returns
  /// `null` and never announces the child twice.
  Future<CodexSubAgentThreadAnnouncement?> handleSubAgentStarted({
    required String childThreadId,
    required String parentThreadId,
    required String parentDirectory,
    required String? agentPath,
    required PluginSessionStatus status,
  }) async {
    if (_subAgentTracker.isChild(sessionId: childThreadId)) return null;
    CodexThreadRecord? read;
    try {
      read = await _connectedThreadRepository.readThread(threadId: childThreadId);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to read sub-agent thread $childThreadId of $parentThreadId; using the activity item",
        error,
        stackTrace,
      );
    }
    final child = CodexThreadRecord(
      id: childThreadId,
      name: read?.agentNickname ?? read?.name ?? agentPath,
      directory: parentDirectory,
      createdAt: read?.createdAt,
      updatedAt: read?.updatedAt,
      model: read?.model,
      modelProvider: read?.modelProvider,
      parentId: parentThreadId,
      agentNickname: read?.agentNickname,
    );
    if (!_subAgentTracker.record(child: child)) return null;
    _subAgentTracker.setChildActive(childId: childThreadId, active: _isActiveStatus(status));
    return CodexSubAgentThreadAnnouncement(
      child: child,
      events: _sessionMapper.mapChildStarted(
        child: child,
        fallbackDirectory: _launchDirectory,
        status: status,
      ),
    );
  }

  Set<String> get deferredRootIds => _subAgentTracker.deferredRootIds;

  void observeRootTurnStarted({required String sessionId}) =>
      _subAgentTracker.cancelDeferredRootIdle(rootId: sessionId);

  void observeSessionStatus({required String sessionId, required PluginSessionStatus status}) =>
      _subAgentTracker.setChildActive(childId: sessionId, active: _isActiveStatus(status));

  /// Applies root/child busy policy to already-mapped notification events and
  /// returns the complete ordered sequence the plugin should buffer.
  List<BridgeSseEvent> coordinateSessionEvents({
    required String? sessionId,
    required bool sessionIsIdle,
    required bool activityChanged,
    required Iterable<BridgeSseEvent> events,
  }) {
    final coordinated = <BridgeSseEvent>[];
    final shouldDeferIdle =
        sessionId != null && sessionIsIdle && _subAgentTracker.busyChildIds(rootId: sessionId).isNotEmpty;
    for (final event in events) {
      if (shouldDeferIdle && _isSessionIdleEvent(event: event, sessionId: sessionId)) {
        _subAgentTracker.deferRootIdle(rootId: sessionId);
      } else {
        coordinated.add(event);
      }
    }
    final releasedRoot = sessionId == null ? null : _subAgentTracker.releaseRootIdleIfSettled(childId: sessionId);
    if (releasedRoot != null) {
      coordinated.addAll(_rootIdleEvents(rootId: releasedRoot));
    }
    if (activityChanged || releasedRoot != null) {
      coordinated.add(const BridgeSseProjectUpdated());
    }
    return coordinated;
  }

  Map<String, PluginSessionStatus> effectiveSessionStatuses({
    required Map<String, PluginSessionStatus> ownStatuses,
  }) => Map.unmodifiable({
    for (final entry in ownStatuses.entries)
      entry.key: _isActiveStatus(entry.value) || _subAgentTracker.busyChildIds(rootId: entry.key).isEmpty
          ? entry.value
          : const PluginSessionStatus.busy(),
  });

  List<PluginProjectActivitySummary> getActiveSessionsSummary({
    required Map<String, PluginSessionStatus> ownStatuses,
    required Set<String> pendingInputSessionIds,
    required Map<String, String> projectIdBySession,
  }) {
    final byProject = <String, List<PluginActiveSession>>{};
    for (final entry in ownStatuses.entries) {
      if (_subAgentTracker.isChild(sessionId: entry.key)) continue;
      final running = _isActiveStatus(entry.value);
      final descendants = _subAgentTracker.descendantsOf(parentId: entry.key);
      final awaitingInput =
          pendingInputSessionIds.contains(entry.key) ||
          descendants.any((child) => pendingInputSessionIds.contains(child.id));
      final busyChildIds = _subAgentTracker.busyChildIds(rootId: entry.key);
      if (!running && !awaitingInput && busyChildIds.isEmpty) continue;
      final projectId = projectIdBySession[entry.key] ?? normalizeProjectDirectory(directory: _launchDirectory);
      (byProject[projectId] ??= []).add(
        PluginActiveSession(
          id: entry.key,
          mainAgentRunning: running,
          awaitingInput: awaitingInput,
          isRetrying: false,
          childSessionIds: busyChildIds,
        ),
      );
    }
    return [
      for (final entry in byProject.entries)
        PluginProjectActivitySummary(
          id: entry.key,
          activeSessions: entry.value,
        ),
    ];
  }

  /// The named session and every persisted or live descendant below it.
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async {
    List<CodexSessionRecord> persisted;
    try {
      persisted = await _catalogRepository.listSessionRecordsInIsolate();
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to enumerate persisted descendants of $sessionId; deleting known live descendants only",
        error,
        stackTrace,
      );
      persisted = const [];
    }
    final childrenByParent = <String, Set<String>>{};
    for (final record in persisted) {
      final parentId = record.parentId;
      if (parentId != null) (childrenByParent[parentId] ??= {}).add(record.id);
    }
    for (final child in _subAgentTracker.descendantsOf(parentId: sessionId)) {
      final parentId = child.parentId;
      if (parentId != null) (childrenByParent[parentId] ??= {}).add(child.id);
    }
    final subtree = <String>[sessionId];
    final seen = <String>{sessionId};
    for (var index = 0; index < subtree.length; index++) {
      for (final childId in childrenByParent[subtree[index]] ?? const <String>{}) {
        if (seen.add(childId)) subtree.add(childId);
      }
    }
    return subtree;
  }

  /// Deletes the already-resolved subtree child-first and clears all
  /// service-owned child lifecycle state. Returns any root-idle events released
  /// when the named session itself was a child of a retained root.
  Future<List<BridgeSseEvent>> deleteSessionSubtree({required List<String> sessionIds}) async {
    if (sessionIds.isEmpty) return const [];
    for (final sessionId in sessionIds) {
      _subAgentTracker.setChildActive(childId: sessionId, active: false);
    }
    final releasedRoot = _subAgentTracker.releaseRootIdleIfSettled(childId: sessionIds.first);
    for (final sessionId in sessionIds.reversed) {
      await _deleteSession(sessionId: sessionId);
    }
    _subAgentTracker.forget(sessionId: sessionIds.first);
    return releasedRoot == null
        ? const []
        : [..._rootIdleEvents(rootId: releasedRoot), const BridgeSseProjectUpdated()];
  }

  bool _isSessionIdleEvent({required BridgeSseEvent event, required String sessionId}) => switch (event) {
    BridgeSseSessionIdle(sessionID: final eventSessionId) => eventSessionId == sessionId,
    BridgeSseSessionStatus(sessionID: final eventSessionId) => eventSessionId == sessionId,
    _ => false,
  };

  List<BridgeSseEvent> _rootIdleEvents({required String rootId}) => [
    BridgeSseSessionStatus(
      sessionID: rootId,
      status: const PluginSessionStatus.idle().toJson(),
    ),
    BridgeSseSessionIdle(sessionID: rootId),
  ];

  bool _isActiveStatus(PluginSessionStatus? status) =>
      status is PluginSessionStatusBusy || status is PluginSessionStatusRetry;

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    return (await _resolveCommands(projectId: projectId)).commands;
  }

  Future<({List<PluginCommand> commands, bool usedFallback})> _resolveCommands({
    required String? projectId,
  }) async {
    final target = normalizeProjectDirectory(directory: projectId ?? _launchDirectory);
    final List<PluginCommand> commands;
    try {
      commands = await _connectedSkillRepository.listCommands(cwd: target);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] skill discovery failed; exposing compact only",
        error,
        stackTrace,
      );
      return (commands: [_compactionCommand], usedFallback: true);
    }
    if (commands.any((command) => command.name == compactionCommandName)) {
      return (commands: commands, usedFallback: false);
    }
    return (commands: [...commands, _compactionCommand], usedFallback: false);
  }

  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    final options = await _resolveModelOptions(projectId: projectId);
    return options.agents;
  }

  Future<PluginProvidersResult> getProviders({
    required String projectId,
  }) async {
    final options = await _resolveModelOptions(projectId: projectId);
    return options.providers;
  }

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({required String projectId}) async {
    final modelOptionsFuture = _resolveModelOptions(projectId: projectId);
    final commandsFuture = _resolveCommands(projectId: projectId);
    final (modelOptions, commands) = await (modelOptionsFuture, commandsFuture).wait;
    return PluginSessionOptionsDiscoveryResult.observed(
      options: PluginSessionOptions(
        agents: modelOptions.agents,
        providers: modelOptions.providers,
        commands: commands.commands,
        completeness: modelOptions.usedFallback || commands.usedFallback
            ? PluginSessionOptionsCompleteness.partial
            : PluginSessionOptionsCompleteness.complete,
      ),
    );
  }

  Future<CodexThreadRecord> startThread({
    required String cwd,
    required String? model,
    required String? modelProvider,
  }) async {
    final thread = await _connectedThreadRepository.startThread(
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
    );
    _loadedThreads.add(thread.id);
    _rememberThreadModel(threadId: thread.id, model: thread.model ?? model);
    return thread;
  }

  Future<CodexThreadRecord?> resumeThreadIfNeeded({
    required String threadId,
    required bool force,
  }) async {
    if (!force && _loadedThreads.contains(threadId)) return null;
    final thread = await _connectedThreadRepository.resumeThread(threadId: threadId);
    _loadedThreads.add(threadId);
    _rememberThreadModel(threadId: threadId, model: thread.model);
    return thread;
  }

  Future<({CodexThreadRecord? resumedThread, String? resolvedModel, String? turnId, bool started})> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    var resumed = await resumeThreadIfNeeded(threadId: threadId, force: false);
    var turnModel = _resolveTurnModel(
      threadId: threadId,
      requestedModel: model,
      collaborationMode: collaborationMode,
    );
    var turnMode = _resolveCollaborationMode(
      model: turnModel,
      collaborationMode: collaborationMode,
    );
    var turnEffort = effort ?? turnMode?.defaultReasoningEffort;
    try {
      final turnId = await _connectedThreadRepository.startTurn(
        threadId: threadId,
        parts: parts,
        clientUserMessageId: clientUserMessageId,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: turnMode,
      );
      if (turnId != null) {
        _rememberThreadModel(threadId: threadId, model: turnModel);
      }
      return (
        resumedThread: resumed,
        resolvedModel: turnModel,
        turnId: turnId,
        started: turnId != null,
      );
    } on CodexThreadNotFoundException {
      resumed = await resumeThreadIfNeeded(threadId: threadId, force: true);
      turnModel = _resolveTurnModel(
        threadId: threadId,
        requestedModel: model,
        collaborationMode: collaborationMode,
      );
      turnMode = _resolveCollaborationMode(
        model: turnModel,
        collaborationMode: collaborationMode,
      );
      turnEffort = effort ?? turnMode?.defaultReasoningEffort;
      final turnId = await _connectedThreadRepository.startTurn(
        threadId: threadId,
        parts: parts,
        clientUserMessageId: clientUserMessageId,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: turnMode,
      );
      if (turnId != null) {
        _rememberThreadModel(threadId: threadId, model: turnModel);
      }
      return (
        resumedThread: resumed,
        resolvedModel: turnModel,
        turnId: turnId,
        started: turnId != null,
      );
    }
  }

  Future<({CodexThreadRecord? resumedThread, String? resolvedModel, String? turnId})> sendCommand({
    required String threadId,
    required String command,
    required String arguments,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    var resumed = await resumeThreadIfNeeded(threadId: threadId, force: false);
    var turnModel = _resolveTurnModel(
      threadId: threadId,
      requestedModel: model,
      collaborationMode: collaborationMode,
    );
    var turnMode = _resolveCollaborationMode(
      model: turnModel,
      collaborationMode: collaborationMode,
    );
    var turnEffort = effort ?? turnMode?.defaultReasoningEffort;
    String? turnId;
    try {
      turnId = await _dispatchCommand(
        threadId: threadId,
        command: command,
        arguments: arguments,
        clientUserMessageId: clientUserMessageId,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: turnMode,
      );
    } on CodexThreadNotFoundException {
      resumed = await resumeThreadIfNeeded(threadId: threadId, force: true);
      turnModel = _resolveTurnModel(
        threadId: threadId,
        requestedModel: model,
        collaborationMode: collaborationMode,
      );
      turnMode = _resolveCollaborationMode(
        model: turnModel,
        collaborationMode: collaborationMode,
      );
      turnEffort = effort ?? turnMode?.defaultReasoningEffort;
      turnId = await _dispatchCommand(
        threadId: threadId,
        command: command,
        arguments: arguments,
        clientUserMessageId: clientUserMessageId,
        model: turnModel,
        effort: turnEffort,
        collaborationMode: turnMode,
      );
    }
    if (command != compactionCommandName) {
      _rememberThreadModel(threadId: threadId, model: turnModel);
    }
    return (
      resumedThread: resumed,
      resolvedModel: command == compactionCommandName ? null : turnModel,
      turnId: turnId,
    );
  }

  Future<String?> _dispatchCommand({
    required String threadId,
    required String command,
    required String arguments,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    if (command == compactionCommandName) {
      await _connectedThreadRepository.compactThread(threadId: threadId);
      return null;
    }
    final invocation = arguments.isEmpty ? "\$$command" : "\$$command $arguments";
    return await _connectedThreadRepository.startTurn(
      threadId: threadId,
      parts: [PluginPromptPart.text(text: invocation)],
      clientUserMessageId: clientUserMessageId,
      model: model,
      effort: effort,
      collaborationMode: collaborationMode,
    );
  }

  String? _resolveTurnModel({
    required String threadId,
    required String? requestedModel,
    required CodexCollaborationMode? collaborationMode,
  }) {
    if (requestedModel != null && requestedModel.isNotEmpty) {
      return requestedModel;
    }
    if (collaborationMode == null) return null;
    return _threadModels[threadId] ??
        _catalogRepository.findSessionById(sessionId: threadId)?.model ??
        _metadataRepository.readConfigDefaults().model;
  }

  CodexCollaborationMode? _resolveCollaborationMode({
    required String? model,
    required CodexCollaborationMode? collaborationMode,
  }) {
    // An unmodeled turn already has Default semantics; Plan must not silently
    // degrade into execution mode when its required model is unavailable.
    if (model == null && collaborationMode == CodexCollaborationMode.defaultMode) {
      return null;
    }
    return collaborationMode;
  }

  void _rememberThreadModel({
    required String threadId,
    required String? model,
  }) {
    if (model != null && model.isNotEmpty) {
      _threadModels[threadId] = model;
    }
  }

  CodexThreadRecord? decodeStartedNotificationParams({
    required Map<String, dynamic> params,
  }) => _threadRepository?.decodeStartedNotificationParams(params: params);

  PluginSession toPluginSession({
    required CodexThreadRecord thread,
    required String fallbackDirectory,
    required String? parentSessionId,
  }) => _sessionMapper.mapThread(
    record: thread,
    fallbackDirectory: fallbackDirectory,
    parentSessionId: parentSessionId,
  );

  void markThreadUnloaded({required String threadId}) {
    _loadedThreads.remove(threadId);
  }

  String directoryForSession({required String sessionId}) {
    final record = _catalogRepository.findSessionById(sessionId: sessionId);
    return normalizeProjectDirectory(
      directory: record?.cwd ?? _launchDirectory,
    );
  }

  Future<void> _deleteSession({required String sessionId}) async {
    final deleted = _catalogRepository.deleteSession(sessionId: sessionId);
    if (deleted) {
      try {
        await _toolOutcomeRepository.deleteSession(sessionId: sessionId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "[codex] failed to delete persisted tool outcomes for $sessionId",
          error,
          stackTrace,
        );
      }
    }
    _loadedThreads.remove(sessionId);
    _threadModels.remove(sessionId);
  }

  Future<CodexSessionMessageRead?> prepareSessionMessageRead({
    required String sessionId,
  }) async {
    final path = _catalogRepository.findRolloutPath(sessionId: sessionId);
    if (path == null) return null;
    Map<String, PluginToolStatus> structuredToolStatusByCallId;
    try {
      structuredToolStatusByCallId = await _toolOutcomeRepository.readStatuses(
        sessionId: sessionId,
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to read persisted tool outcomes for $sessionId",
        error,
        stackTrace,
      );
      structuredToolStatusByCallId = const {};
    }
    return CodexSessionMessageRead._(
      messages: _messageRepository.prepareMessageRead(
        rolloutPath: path,
        sessionId: sessionId,
      ),
      structuredToolStatusByCallId: structuredToolStatusByCallId,
      config: _metadataRepository.readConfigDefaults(),
    );
  }

  List<PluginMessageWithParts> getSessionMessages({
    required String sessionId,
    required CodexSessionMessageRead read,
    required PluginSessionStatus sessionStatus,
  }) {
    return _messageRepository.projectMessages(
      read: read._messages,
      sessionId: sessionId,
      replayToolDisposition: switch (sessionStatus) {
        PluginSessionStatusIdle() => CodexReplayToolDisposition.terminalize,
        PluginSessionStatusBusy() || PluginSessionStatusRetry() => CodexReplayToolDisposition.preserveRunning,
      },
      structuredToolStatusByCallId: read._structuredToolStatusByCallId,
      config: read._config,
    );
  }

  /// Resolves project defaults across the rollout catalog and Codex config.
  ({String? modelID, String providerID}) resolveModelDefaults({
    required String projectId,
  }) {
    final config = _metadataRepository.readConfigDefaults();
    final target = normalizeProjectDirectory(directory: projectId);
    for (final record in _catalogRepository.listSessionRecords()) {
      final directory = normalizeProjectDirectory(
        directory: record.cwd ?? _launchDirectory,
      );
      if (directory == target || p.isWithin(target, directory)) {
        return (
          modelID: record.model ?? config.model,
          providerID: record.modelProvider ?? config.modelProvider ?? "openai",
        );
      }
    }
    return (
      modelID: config.model,
      providerID: config.modelProvider ?? "openai",
    );
  }

  String? selectCatalogDefaultModel({
    required String? scopedModelID,
    required List<String> catalogModelIds,
    required String? catalogDefaultId,
  }) {
    if (scopedModelID != null && catalogModelIds.contains(scopedModelID)) {
      return scopedModelID;
    }
    if (catalogDefaultId != null) return catalogDefaultId;
    return catalogModelIds.isEmpty ? null : catalogModelIds.first;
  }

  Future<
    ({
      List<PluginAgent> agents,
      PluginProvidersResult providers,
      bool usedFallback,
    })
  >
  _resolveModelOptions({required String projectId}) async {
    final (:modelID, :providerID) = resolveModelDefaults(
      projectId: projectId,
    );
    final catalogResult = await _listModels();
    final catalog = catalogResult.catalog;
    final models = catalog.models.isEmpty
        ? [
            if (modelID != null)
              PluginModel(
                id: modelID,
                name: modelID,
                variants: const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ]
        : catalog.models;
    final selectedModelID = selectCatalogDefaultModel(
      scopedModelID: modelID,
      catalogModelIds: [for (final model in models) model.id],
      catalogDefaultId: catalog.defaultModelID,
    );
    final agentModel = selectedModelID == null
        ? null
        : PluginAgentModel(
            modelID: selectedModelID,
            providerID: providerID,
            variant: null,
          );
    return (
      agents: [
        for (final collaborationMode in CodexCollaborationMode.values)
          if (agentModel != null || collaborationMode == CodexCollaborationMode.defaultMode)
            PluginAgent(
              name: collaborationMode.agentName,
              description: collaborationMode.description,
              model: agentModel,
              mode: PluginAgentMode.primary,
              hidden: false,
            ),
      ],
      providers: PluginProvidersResult(
        providers: selectedModelID == null
            ? const []
            : [
                PluginProvider(
                  id: providerID,
                  name: _providerDisplayName(providerID: providerID),
                  authType: PluginProviderAuthType.unknown,
                  models: models,
                  defaultModelID: selectedModelID,
                ),
              ],
      ),
      usedFallback: catalogResult.usedFallback || (catalog.models.isEmpty && modelID != null),
    );
  }

  Future<({CodexModelCatalog catalog, bool usedFallback})> _listModels() async {
    final repository = _modelRepository;
    if (repository == null) {
      return (
        catalog: (defaultModelID: null, models: const <PluginModel>[]),
        usedFallback: true,
      );
    }
    try {
      return (catalog: await repository.listModels(), usedFallback: false);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] model discovery failed; using configured fallback",
        error,
        stackTrace,
      );
      return (
        catalog: (defaultModelID: null, models: const <PluginModel>[]),
        usedFallback: true,
      );
    }
  }

  String _providerDisplayName({required String providerID}) {
    return switch (providerID.toLowerCase()) {
      "openai" => "OpenAI",
      "anthropic" => "Anthropic",
      "google" => "Google",
      "mistral" => "Mistral",
      "groq" => "Groq",
      "xai" => "xAI",
      "deepseek" => "DeepSeek",
      "azure" => "Azure OpenAI",
      "amazon-bedrock" || "bedrock" => "Amazon Bedrock",
      _ => providerID,
    };
  }

  CodexThreadRepository get _connectedThreadRepository {
    final repository = _threadRepository;
    if (repository == null) {
      throw StateError("codex app-server API is not connected");
    }
    return repository;
  }

  CodexSkillRepository get _connectedSkillRepository {
    final repository = _skillRepository;
    if (repository == null) {
      throw StateError("codex app-server API is not connected");
    }
    return repository;
  }
}
