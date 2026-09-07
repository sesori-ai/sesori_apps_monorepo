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
  required final List<CodexThreadRecord> _children,
  required final Map<String, PluginToolStatus> _structuredToolStatusByCallId,
  required final CodexConfigDefaults _config,
});

final class const CodexSubAgentThreadAnnouncement({
  required final CodexThreadRecord child,
  required final PluginSessionStatus status,
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
  final Set<String> _announcedSubAgentThreadIds = {};
  final Set<String> _deletedSubAgentThreadIds = {};

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
    _announcedSubAgentThreadIds.clear();
    _deletedSubAgentThreadIds.clear();
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

  /// Restores persisted parent relationships before a new app-server
  /// connection can deliver child approval requests. Persisted children are
  /// inactive until live status evidence says otherwise.
  Future<void> hydratePersistedChildAncestry() async {
    final List<CodexSessionRecord> records;
    try {
      records = await _catalogRepository.listSessionRecordsInIsolate();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to hydrate persisted child ancestry", error, stackTrace);
      return;
    }
    final pending = {
      for (final record in records)
        if (record.parentId != null) record.id: record,
    };
    while (pending.isNotEmpty) {
      var progressed = false;
      for (final record in pending.values.toList(growable: false)) {
        if (pending.containsKey(record.parentId)) continue;
        _recordPersistedChild(record: record);
        pending.remove(record.id);
        progressed = true;
      }
      if (progressed) continue;
      Log.w("[codex] skipped cyclic persisted child ancestry");
      break;
    }
  }

  void _recordPersistedChild({required CodexSessionRecord record}) =>
      _subAgentTracker.record(child: _sessionMapper.mapPersistedThread(record: record));

  List<CodexThreadRecord> knownChildThreads({required String sessionId}) =>
      _subAgentTracker.childrenOf(parentId: sessionId);

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
    if (_deletedSubAgentThreadIds.contains(parentThreadId) ||
        _deletedSubAgentThreadIds.contains(childThreadId) ||
        !_announcedSubAgentThreadIds.add(childThreadId)) {
      return null;
    }
    final threadRepository = _connectedThreadRepository;
    // Record the activity's authoritative ancestry before best-effort
    // `thread/read`: approval requests arrive on an independent stream and
    // must resolve to the root even while that enrichment is in flight. A
    // child hydrated from disk is known but has not yet been announced on
    // this connection, so preserve its metadata and continue.
    final trackedChild = _subAgentTracker.child(sessionId: childThreadId);
    var child =
        trackedChild ??
        CodexThreadRecord(
          id: childThreadId,
          name: agentPath,
          directory: parentDirectory,
          createdAt: null,
          updatedAt: null,
          model: null,
          modelProvider: null,
          parentId: parentThreadId,
          agentNickname: null,
          agentPath: agentPath,
        );
    if (trackedChild == null && !_subAgentTracker.record(child: child)) {
      _announcedSubAgentThreadIds.remove(childThreadId);
      return null;
    }
    // The observed 0.148.0 sequence reports a pre-start idle status before
    // this authoritative activity fact, then active afterwards. Treat the
    // child as pending now so a root completion cannot slip through that gap.
    final startedStatus = _isActiveStatus(status) ? status : const PluginSessionStatus.busy();
    _subAgentTracker.setChildActive(childId: childThreadId, active: true);
    CodexThreadRecord? read;
    try {
      read = await threadRepository.readThread(threadId: childThreadId);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] failed to read sub-agent thread $childThreadId of $parentThreadId; using the activity item",
        error,
        stackTrace,
      );
    }
    if (!identical(_threadRepository, threadRepository) ||
        _deletedSubAgentThreadIds.contains(parentThreadId) ||
        _deletedSubAgentThreadIds.contains(childThreadId)) {
      return null;
    }
    if (read != null) {
      child = CodexThreadRecord(
        id: childThreadId,
        name: read.agentNickname ?? read.name ?? agentPath,
        directory: parentDirectory,
        createdAt: read.createdAt,
        updatedAt: read.updatedAt,
        model: read.model,
        modelProvider: read.modelProvider,
        parentId: parentThreadId,
        agentNickname: read.agentNickname,
        agentPath: agentPath ?? trackedChild?.agentPath,
      );
      _subAgentTracker.replaceChild(child: child);
    }
    return CodexSubAgentThreadAnnouncement(
      child: child,
      status: startedStatus,
      events: _sessionMapper.mapChildStarted(
        child: child,
        fallbackDirectory: _launchDirectory,
        status: startedStatus,
      ),
    );
  }

  Set<String> get deferredRootIds => _subAgentTracker.deferredRootIds;

  bool isActiveTrackedChild({required String sessionId}) => _subAgentTracker.isChildActive(sessionId: sessionId);

  void markSessionsDeleted({required Iterable<String> sessionIds}) {
    _deletedSubAgentThreadIds.addAll(sessionIds);
  }

  /// The source sessions whose pending input belongs on [sessionId]'s screen,
  /// plus the top-most root id each snapshot should use for display routing.
  ({String displaySessionId, List<String> sourceSessionIds}) pendingInputScope({
    required String sessionId,
  }) {
    final displaySessionId = _subAgentTracker.rootOf(sessionId: sessionId) ?? sessionId;
    return (
      displaySessionId: displaySessionId,
      sourceSessionIds: [
        sessionId,
        for (final child in _subAgentTracker.descendantsOf(parentId: sessionId)) child.id,
      ],
    );
  }

  /// Restores canonical child ancestry from a resumed thread response. This
  /// path replaces the live spawn activity after a bridge reconnect.
  void observeResumedThread({
    required CodexThreadRecord thread,
    required PluginSessionStatus status,
  }) {
    final parentId = thread.parentId;
    if (parentId == null ||
        _deletedSubAgentThreadIds.contains(parentId) ||
        _deletedSubAgentThreadIds.contains(thread.id)) {
      return;
    }
    _subAgentTracker.record(child: thread);
    _subAgentTracker.setChildActive(childId: thread.id, active: _isActiveStatus(status));
  }

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
    required bool sessionClosed,
    required Iterable<BridgeSseEvent> events,
  }) {
    final coordinated = <BridgeSseEvent>[
      if (sessionClosed && activityChanged && sessionId != null && _subAgentTracker.isChild(sessionId: sessionId))
        BridgeSseSessionStatus(
          sessionID: sessionId,
          status: const PluginSessionStatus.idle(),
        ),
    ];
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
  }) {
    final effective = Map<String, PluginSessionStatus>.of(ownStatuses);
    for (final rootId in _subAgentTracker.activeRootIds) {
      if (!_isActiveStatus(effective[rootId])) {
        effective[rootId] = const PluginSessionStatus.busy();
      }
    }
    return Map.unmodifiable(effective);
  }

  List<PluginProjectActivitySummary> getActiveSessionsSummary({
    required Map<String, PluginSessionStatus> ownStatuses,
    required Set<String> pendingInputSessionIds,
    required Map<String, String> projectIdBySession,
  }) {
    final rootSessionIds = {
      for (final sessionId in ownStatuses.keys)
        if (!_subAgentTracker.isChild(sessionId: sessionId)) sessionId,
      ..._subAgentTracker.activeRootIds,
      for (final sessionId in pendingInputSessionIds) _subAgentTracker.rootOf(sessionId: sessionId) ?? sessionId,
    };
    final byProject = <String, List<PluginActiveSession>>{};
    for (final sessionId in rootSessionIds) {
      final running = _isActiveStatus(ownStatuses[sessionId]);
      final descendants = _subAgentTracker.descendantsOf(parentId: sessionId);
      final awaitingInput =
          pendingInputSessionIds.contains(sessionId) ||
          descendants.any((child) => pendingInputSessionIds.contains(child.id));
      final busyChildIds = _subAgentTracker.busyChildIds(rootId: sessionId);
      if (!running && !awaitingInput && busyChildIds.isEmpty) continue;
      final projectId = projectIdBySession[sessionId] ?? directoryForSession(sessionId: sessionId);
      (byProject[projectId] ??= []).add(
        PluginActiveSession(
          id: sessionId,
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
    markSessionsDeleted(sessionIds: sessionIds);
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
      status: const PluginSessionStatus.idle(),
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
    Future<({CodexThreadRecord? resumedThread, String? resolvedModel, String? turnId, bool started})> start(
      _PreparedTurn prepared,
    ) async {
      final turnId = await _connectedThreadRepository.startTurn(
        threadId: threadId,
        parts: parts,
        clientUserMessageId: clientUserMessageId,
        model: prepared.model,
        effort: prepared.effort,
        collaborationMode: prepared.mode,
      );
      if (turnId != null) {
        _rememberThreadModel(threadId: threadId, model: prepared.model);
      }
      return (
        resumedThread: prepared.resumedThread,
        resolvedModel: prepared.model,
        turnId: turnId,
        started: turnId != null,
      );
    }

    final prepared = await _prepareTurn(
      threadId: threadId,
      forceResume: false,
      model: model,
      effort: effort,
      collaborationMode: collaborationMode,
    );
    try {
      return await start(prepared);
    } on CodexThreadNotFoundException {
      // Exactly one forced-resume retry; the resume may change the thread's
      // model, so everything derived from it is recomputed.
      return await start(
        await _prepareTurn(
          threadId: threadId,
          forceResume: true,
          model: model,
          effort: effort,
          collaborationMode: collaborationMode,
        ),
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
    Future<String?> dispatch(_PreparedTurn prepared) => _dispatchCommand(
      threadId: threadId,
      command: command,
      arguments: arguments,
      clientUserMessageId: clientUserMessageId,
      model: prepared.model,
      effort: prepared.effort,
      collaborationMode: prepared.mode,
    );

    var prepared = await _prepareTurn(
      threadId: threadId,
      forceResume: false,
      model: model,
      effort: effort,
      collaborationMode: collaborationMode,
    );
    String? turnId;
    try {
      turnId = await dispatch(prepared);
    } on CodexThreadNotFoundException {
      // Exactly one forced-resume retry; the resume may change the thread's
      // model, so everything derived from it is recomputed.
      prepared = await _prepareTurn(
        threadId: threadId,
        forceResume: true,
        model: model,
        effort: effort,
        collaborationMode: collaborationMode,
      );
      turnId = await dispatch(prepared);
    }
    if (command != compactionCommandName) {
      _rememberThreadModel(threadId: threadId, model: prepared.model);
    }
    return (
      resumedThread: prepared.resumedThread,
      resolvedModel: command == compactionCommandName ? null : prepared.model,
      turnId: turnId,
    );
  }

  /// Resumes the thread when needed and derives the model, collaboration mode
  /// and effort a turn or command runs with.
  Future<_PreparedTurn> _prepareTurn({
    required String threadId,
    required bool forceResume,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    final resumedThread = await resumeThreadIfNeeded(threadId: threadId, force: forceResume);
    final turnModel = _resolveTurnModel(
      threadId: threadId,
      requestedModel: model,
      collaborationMode: collaborationMode,
    );
    final turnMode = _resolveCollaborationMode(model: turnModel, collaborationMode: collaborationMode);
    return (
      resumedThread: resumedThread,
      model: turnModel,
      mode: turnMode,
      effort: effort ?? turnMode?.defaultReasoningEffort,
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
    final messages = _messageRepository.prepareMessageRead(rolloutPath: path, sessionId: sessionId);
    final children = messages.hasSubtasks
        ? [
            for (final record in await _catalogRepository.listSessionRecordsInIsolate())
              if (record.parentId == sessionId) _sessionMapper.mapPersistedThread(record: record),
          ]
        : const <CodexThreadRecord>[];
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
      messages: messages,
      children: children,
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
      children: [
        ...knownChildThreads(sessionId: sessionId),
        ...read._children,
      ],
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

typedef _PreparedTurn = ({
  CodexThreadRecord? resumedThread,
  String? model,
  CodexCollaborationMode? mode,
  String? effort,
});
