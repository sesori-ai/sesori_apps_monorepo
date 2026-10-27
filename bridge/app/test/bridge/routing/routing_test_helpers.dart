import "dart:async";

import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/repositories/external_action_repository.dart";
import "package:sesori_bridge/src/repositories/form_repository.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_session_status_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_bridge/src/repositories/mappers/prompt_part_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/repositories/models/session_abort_result.dart";
import "package:sesori_bridge/src/repositories/models/session_continuation_record.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/pending_interaction_support.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/routing/request_handler.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/pending_interaction_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_unseen_service.dart";
import "package:sesori_bridge/src/services/session_view_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/single_plugin_repository_test_support.dart";

export "../../helpers/fakes/fake_bridge_plugin.dart";
export "../../helpers/fakes/fake_repository_fakes.dart";

/// Builds a real [SessionUnseenService] backed by [db] for handler/router tests.
SessionUnseenService buildTestSessionUnseenService(AppDatabase db, BridgePluginApi plugin) {
  const calculator = SessionUnseenCalculator();
  return SessionUnseenService(
    unseenRepository: SessionUnseenRepository(
      sessionDao: db.sessionDao,
      calculator: calculator,
    ),
    projectRepository: singlePluginProjectRepository(
      gitCliApi: FakeGitCliApi(),
      projectsDao: db.projectsDao,
      sessionDao: db.sessionDao,
      unseenCalculator: calculator,
      filesystemApi: FakeFilesystemApi(),
    ),
    viewTracker: SessionViewTracker(),
  );
}

({PendingInteractionService service, SessionOperationDispatcher dispatcher}) buildTestPendingInteractionService({
  required AppDatabase database,
  required BridgePluginApi plugin,
}) {
  final sessionRepository = singlePluginSessionRepository(
    plugin: plugin,
    sessionDao: database.sessionDao,
    projectsDao: database.projectsDao,
    unseenCalculator: const SessionUnseenCalculator(),
  );
  final dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
  return (
    dispatcher: dispatcher,
    service: PendingInteractionService(
      formRepository: FormRepository(
        runtime: createTestPluginRuntime(plugins: [plugin]),
        pendingSupport: PendingInteractionSupport(sessionDao: database.sessionDao),
      ),
      externalActionRepository: ExternalActionRepository(
        runtime: createTestPluginRuntime(plugins: [plugin]),
        pendingSupport: PendingInteractionSupport(sessionDao: database.sessionDao),
      ),
      permissionRepository: singlePluginPermissionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
      ),
      questionRepository: singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      dispatcher: dispatcher,
      archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
    ),
  );
}

/// Convenience factory for [RelayRequest] instances in tests.
RelayRequest makeRequest(
  String method,
  String path, {
  Map<String, String> headers = const {},
  String? body,
}) => RelayMessage.request(
  id: "test-id",
  method: method,
  path: path,
  headers: headers,
  body: body,
) as RelayRequest;

extension RequestHandlerTestMatching on RequestHandlerBase {
  bool canHandle(RelayRequest request) {
    final method = HttpMethod.parseExternal(rawMethod: request.method);
    if (method == null) return false;
    return matches(requestMethod: method, target: Uri.parse(request.path));
  }

  RequestTargetParams extractParams(RelayRequest request) => extractTargetParams(target: Uri.parse(request.path));

  Future<RelayResponse> routeForTest(RelayRequest request) async {
    final targetParams = extractTargetParams(target: Uri.parse(request.path));
    final outcome = await routeInternal(request: request, targetParams: targetParams);
    return outcome.response;
  }
}

/// Hand-written fake [SessionDao] for testing.
class FakeSessionDao() {
  final Map<String, SessionDto> _sessions = {};

  /// Set up a session in the fake database.
  void setSession(SessionDto session) {
    _sessions[session.sessionId] = session;
  }

  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds}) async {
    final result = <String, SessionDto>{};
    for (final id in sessionIds) {
      if (_sessions.containsKey(id)) {
        result[id] = _sessions[id]!;
      }
    }
    return result;
  }

  Future<void> insertSession({
    required String sessionId,
    required String backendSessionId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required String pluginId,
  }) async {
    _sessions[sessionId] = SessionDto(
      fastMode: false,
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      projectId: projectId,
      parentSessionId: null,
      directory: worktreePath ?? projectId,
      worktreePath: worktreePath,
      branchName: null,
      isDedicated: isDedicated,
      archivedAt: null,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      lastAgent: lastAgent,
      lastAgentModel: lastAgentModel,
      createdAt: createdAt,
      updatedAt: createdAt,
      projectionUpdatedAt: createdAt,
      lastActivityAt: null,
      lastSeenAt: null,
      lastUserMessageAt: null,
      pluginId: pluginId,
      title: null,
      catalogTitle: null,
      approvalOverride: null,
    );
  }

  Future<SessionDto?> getSession({required String sessionId}) async => _sessions[sessionId];

  Future<void> setArchived({
    required String sessionId,
    required int archivedAt,
    required int updatedAt,
    required int projectionUpdatedAt,
  }) async {
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;
      _sessions[sessionId] = session.copyWith(archivedAt: archivedAt);
    }
  }

  Future<void> deleteSession({required String sessionId}) async {
    _sessions.remove(sessionId);
  }
}

DeletedSessionSubtree _deletedSession(String sessionId) =>
    (session: _deletedSessionInfo(sessionId), sessionIds: [sessionId]);

Session _deletedSessionInfo(String sessionId) => Session(
  approvalOverride: null,
  autoContinuation: null,
  branchName: null,
  id: sessionId,
  pluginId: "fake",
  projectID: "",
  directory: "",
  parentID: null,
  title: null,
  time: null,
  promptDefaults: null,
  lastUserActivityAt: null,
);

Future<void> recordSessionBinding({
  required AppDatabase database,
  required String sessionId,
  required String backendSessionId,
  required String pluginId,
  required String projectId,
  required String? parentSessionId,
}) async {
  await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  if (parentSessionId == null) {
    await database.sessionDao.insertSession(
      fastMode: false,
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      projectId: projectId,
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      baseBranch: null,
      baseCommit: null,
      lastAgent: null,
      lastAgentModel: null,
      pluginId: pluginId,
    );
    return;
  }
  await database.sessionDao.insertObservedChild(
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    projectId: projectId,
    parentSessionId: parentSessionId,
    directory: projectId,
    catalogTitle: null,
    archivedAt: null,
    createdAt: 1,
    updatedAt: 1,
    projectionUpdatedAt: 1,
    pluginId: pluginId,
  );
}

Session _sharedSessionFromPlugin(PluginSession session, String pluginId) {
  return Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: session.id,
    pluginId: pluginId,
    projectID: session.projectID,
    directory: session.directory,
    parentID: session.parentID,
    title: session.title,
    time: switch (session.time) {
      PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
        created: created,
        updated: updated,
        archived: archived,
      ),
      null => null,
    },
    promptDefaults: null,
    lastUserActivityAt: null,
  );
}

/// Test-friendly [SessionRepository] that delegates to a [FakeBridgePlugin]
/// and [FakeSessionDao], so handler tests can configure plugin/DAO behaviour
/// without needing real implementations.
class FakeSessionRepository({
  required final FakeBridgePlugin _plugin,
  FakeSessionDao? sessionDao,
  final AppDatabase? _persistenceDatabase,
}) implements SessionRepository {
  @override
  AutoContinuationAvailability quotaReportingAvailability({required String pluginId}) =>
      AutoContinuationAvailability.unavailable;

  @override
  Future<SessionContinuationReadiness> getQuotaContinuationReadiness({required String sessionId}) async =>
      SessionContinuationReadiness.unavailable;

  @override
  Stream<SessionBindingsCommitted> get bindingCommits => const Stream.empty();

  @override
  Future<List<QueuedSessionPrompt>> getQueuedPrompts({required String sessionId}) async =>
      (await _plugin.getQueuedPrompts(sessionId: sessionId)).toSharedQueuedPrompts();

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) =>
      _plugin.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);

  @override
  int captureProjectionTimestamp() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Set<String>> getStoredSessionIdsForPlugin({required String pluginId}) async => const {};

  @override
  Future<void> dispose() async {}

  final FakeSessionDao _sessionDao = sessionDao ?? FakeSessionDao();
  int getSessionsCallCount = 0;
  ({String projectId, int? start, int? limit})? lastGetSessionsArgs;
  String? projectPathResult;
  Object? publicationError;

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: _plugin.id);

  @override
  Future<SessionMessagesSnapshot> getSessionMessages({required String sessionId}) async {
    final pluginMessages = await _plugin.getSessionMessages(sessionId);
    return (
      messages: pluginMessages.toSharedMessageWithParts(sessionId: sessionId),
      promptDefaults: pluginMessages.latestPromptDefaults(),
    );
  }

  /// Recorded setSessionTitleIfStored calls (sessionId → title).
  final List<({String sessionId, String? title})> recordedTitles = [];

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    recordedTitles.add((sessionId: sessionId, title: title));
    return true;
  }

  @override
  Future<Session?> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async => null;

  @override
  Future<SessionApprovalMode?> resolveApprovalOverride({required String sessionId}) async => null;

  @override
  Future<bool> hasYoloApprovalOverride() async => false;

  @override
  Future<Session?> setGeneratedSessionTitleIfAbsent({required String sessionId, required String title}) async {
    final stored = await _sessionDao.getSession(sessionId: sessionId);
    if (stored == null || stored.title != null) return null;
    return Session(
      approvalOverride: null,
      autoContinuation: null,
      branchName: stored.branchName,
      id: stored.sessionId,
      pluginId: stored.pluginId,
      projectID: stored.projectId,
      directory: stored.directory,
      parentID: stored.parentSessionId,
      title: title,
      time: SessionTime(created: stored.createdAt, updated: stored.updatedAt, archived: stored.archivedAt),
      promptDefaults: null,
      lastUserActivityAt: stored.lastUserMessageAt,
    );
  }

  @override
  Future<DeletedSessionSubtree> deleteSession({required String sessionId}) async => _deletedSession(sessionId);

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async => false;

  @override
  Future<List<String>> get persistedSessionCleanupPluginIds async => const [];

  @override
  Future<Set<String>> getTombstonedBackendSessionIdsForCleanup({required String pluginId}) async => const {};

  @override
  Future<void> deletePersistedSession({required String pluginId, required String backendSessionId}) async {}

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async => [
    for (final summary in _plugin.getActiveSessionsSummary())
      ProjectActivitySummary(
        id: summary.id,
        activeSessions: [
          for (final active in summary.activeSessions)
            ActiveSession(
              id: active.id,
              mainAgentRunning: active.mainAgentRunning,
              awaitingInput: active.awaitingInput,
              isRetrying: active.isRetrying,
              childSessionIds: active.childSessionIds,
              lastUserActivityAt: null,
              updatedAt: null,
            ),
        ],
      ),
  ];

  @override
  Future<Session> createSession({
    required String pluginId,
    required String projectId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required String? userVisibleText,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required bool isDedicated,
    required String? worktreePath,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
  }) async => const Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: "",
    pluginId: "fake",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    promptDefaults: null,
    lastUserActivityAt: null,
  );

  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    getSessionsCallCount++;
    lastGetSessionsArgs = (projectId: projectId, start: start, limit: limit);
    final pluginSessions = await _plugin.getSessions(
      projectId: projectId,
      start: start,
      limit: limit,
    );
    final sessions = pluginSessions.map((session) => _sharedSessionFromPlugin(session, _plugin.id)).toList();
    final sessionIds = sessions.map((s) => s.id).toList();
    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);
    final mergedSessions = sessions.map((session) {
      final dbSession = dbSessions[session.id];
      if (dbSession != null) {
        final currentTime = session.time;
        final mergedTime = currentTime != null
            ? currentTime.copyWith(archived: dbSession.archivedAt)
            : SessionTime(created: 0, updated: 0, archived: dbSession.archivedAt);
        return session.copyWith(
          time: mergedTime,
          hasWorktree: dbSession.worktreePath != null,
        );
      }
      return session;
    }).toList();
    final database = _persistenceDatabase;
    if (database != null) {
      if (publicationError case final error?) throw error;
      await database.transaction(() async {
        await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
        await database.sessionDao.insertSessionsIfMissing(
          pluginId: _plugin.id,
          sessions: [
            for (final session in mergedSessions)
              (
                sessionId: session.id,
                backendSessionId: session.id,
                projectId: projectId,
                directory: session.directory,
                createdAt: session.time?.created ?? DateTime.now().millisecondsSinceEpoch,
                archivedAt: session.time?.archived,
              ),
          ],
        );
      });
    }
    return mergedSessions;
  }

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async {
    final pluginSessions = await _plugin.getChildSessions(sessionId);
    return pluginSessions.map((session) => _sharedSessionFromPlugin(session, _plugin.id)).toList();
  }

  @override
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async {
    final stored = await _sessionDao.getSession(sessionId: sessionId);
    return stored == null ? const [] : [sessionId];
  }

  @override
  Future<Set<String>> getExistingSessionIds({required Set<String> sessionIds}) async {
    final rows = await _sessionDao.getSessionsByIds(sessionIds: sessionIds.toList(growable: false));
    return rows.keys.toSet();
  }

  @override
  Future<Set<String>> getArchivedSessionIds({required Set<String> sessionIds}) async {
    final rows = await _sessionDao.getSessionsByIds(sessionIds: sessionIds.toList(growable: false));
    return {
      for (final entry in rows.entries)
        if (entry.value.archivedAt != null) entry.key,
    };
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String worktreePath,
  }) async => false;

  @override
  Future<String?> getProjectPath({required String projectId}) async => projectPathResult;

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
  }

  @override
  Future<String?> getSessionTitle({required String sessionId}) async {
    final row = await _sessionDao.getSession(sessionId: sessionId);
    return row?.title ?? row?.catalogTitle;
  }

  @override
  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async => null;

  @override
  Future<Map<String, String>> getSessionIdsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async => const {};

  @override
  Future<Session?> recordSessionCompletion({
    required String sessionId,
    required String pluginId,
    required int generation,
    required int completedAt,
  }) async => null;

  @override
  Future<StoredSession?> updateObservedSessionProjection({
    required String pluginId,
    required int generation,
    required Session observed,
    required bool updateCatalogTitle,
    required int projectionUpdatedAt,
  }) async => await getStoredSessionByBackendId(pluginId: pluginId, backendSessionId: observed.id);

  @override
  Future<StoredSession?> insertObservedChild({
    required String pluginId,
    required int generation,
    required Session observed,
    required StoredSession parent,
    required int projectionUpdatedAt,
  }) async => null;

  @override
  Future<StoredSession> requireStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final stored = await getStoredSession(sessionId: sessionId);
    if (stored == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    return stored;
  }

  @override
  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final stored = await requireStoredSession(sessionId: sessionId, operation: operation);
    await ensurePluginRoutable(pluginId: stored.pluginId, operation: operation);
    return stored;
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => null;

  @override
  Future<SessionStatusResponse> getSessionStatuses() async {
    final statuses = await _plugin.getSessionStatuses();
    return SessionStatusResponse(
      statuses: {
        for (final entry in statuses.entries)
          if (await _sessionDao.getSession(sessionId: entry.key) case final stored?)
            stored.sessionId: entry.value.toSharedSessionStatus(),
      },
    );
  }

  @override
  Future<SessionStatus?> getSessionStatus({required String sessionId}) async {
    final stored = await _sessionDao.getSession(sessionId: sessionId);
    if (stored == null) return null;
    return (await _plugin.getSessionStatuses())[stored.backendSessionId]?.toSharedSessionStatus();
  }

  @override
  SessionStatus stampLiveStatus({required String sessionId, required SessionStatus status}) => status;

  @override
  void markSessionIdle({required String sessionId}) {}

  @override
  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) async {
    if (pluginId == _plugin.id) return;
    throw PluginOperationException(
      operation.name,
      statusCode: 503,
      message: "plugin $pluginId is not running",
    );
  }

  @override
  Future<void> archiveStoredSession({
    required String sessionId,
    required int archivedAt,
  }) async {}

  @override
  Future<SessionPromptDefaults?> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async => SessionPromptDefaults(agent: agent, model: agentModel);

  @override
  Future<void> updateRequestedPromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
    required bool fastMode,
  }) async {}

  @override
  Future<({String pluginId, String projectId})?> findSessionOptionsScope({required String sessionId}) async => null;

  @override
  Future<SessionAbortResult> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
    required bool useAtomicStop,
  }) async {
    final result = await _plugin.abortSession(
      sessionId: sessionId,
      subAgents: subAgents.toPlugin(),
      useAtomicStop: useAtomicStop,
      knownSubAgentSessionIds: const {},
    );
    return switch (result) {
      PluginAbortAccepted(:final workKept, :final subAgentsHandled) => SessionAborted(
        workKept: workKept,
        subAgentsHandled: subAgentsHandled,
      ),
      final PluginAbortRejectedSubAgentsRunning rejection => SessionAbortRejected(rejection: rejection.toShared()),
      PluginAbortNotPerformed(:final reason) => SessionAbortNotPerformed(
        refusal: SessionAbortNotPerformedRefusal(reason: reason.toShared()),
      ),
    };
  }

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendCommand(
      fastMode: fastMode,
      promptId: "prompt-1",
      sessionId: sessionId,
      command: command,
      arguments: arguments,
      userVisibleArguments: userVisibleArguments,
      variant: _toPluginVariant(variant),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  @override
  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) async {
    final normalizedProjectId = projectId?.trim();
    final commands = await _plugin.getCommands(
      projectId: normalizedProjectId == null || normalizedProjectId.isEmpty ? null : normalizedProjectId,
    );
    return CommandListResponse(
      items: commands.map((command) => command.toSharedCommandInfo()).toList(growable: false),
    );
  }

  @override
  Future<void> sendPrompt({
    required String promptId,
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendPrompt(
      fastMode: fastMode,
      promptId: "prompt-1",
      sessionId: sessionId,
      parts: parts.map((part) => part.toPlugin()).toList(growable: false),
      variant: _toPluginVariant(variant),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  PluginSessionVariant? _toPluginVariant(SessionVariant? variant) {
    return switch (variant) {
      SessionVariant(:final id) => PluginSessionVariant(id: id),
      null => null,
    };
  }

  @override
  Future<void> renameSession({required String sessionId, required String title}) async {}

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}
