import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_session_status_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_bridge/src/repositories/mappers/prompt_part_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/pull_request_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/routing/request_handler.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/device_canvas_claim_service.dart";
import "package:sesori_bridge/src/services/pending_interaction_service.dart";
import "package:sesori_bridge/src/services/pr_sync_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_unseen_service.dart";
import "package:sesori_bridge/src/services/session_view_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/fakes/fake_repository_fakes.dart";
import "../../helpers/single_plugin_repository_test_support.dart";

export "../../helpers/fakes/fake_bridge_plugin.dart";
export "../../helpers/fakes/fake_repository_fakes.dart";

/// Builds a real [SessionUnseenService] backed by [db] for handler/router tests.
SessionUnseenService buildTestSessionUnseenService(AppDatabase db, BridgePluginApi plugin) {
  const calculator = SessionUnseenCalculator();
  final deviceCanvasClaimService = DeviceCanvasClaimService(
    repository: DeviceCanvasClaimRepository(
      claimDao: db.deviceCanvasClaimDao,
      sessionDao: db.sessionDao,
      now: () => DateTime.now().millisecondsSinceEpoch,
    ),
    integrationState: DeviceCanvasIntegrationState(),
  );
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
    deviceCanvasClaimService: deviceCanvasClaimService,
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
    pullRequestDao: database.pullRequestDao,
    unseenCalculator: const SessionUnseenCalculator(),
  );
  final dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
  return (
    dispatcher: dispatcher,
    service: PendingInteractionService(
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
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required String pluginId,
  }) async {
    _sessions[sessionId] = SessionDto(
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      projectId: projectId,
      parentSessionId: null,
      directory: worktreePath ?? projectId,
      worktreePath: worktreePath,
      branchName: branchName,
      currentBranchName: null,
      currentGithubRepositoryIdentity: null,
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

  Future<List<SessionDto>> getSessionsByProject({required String projectId}) async {
    return _sessions.values.where((s) => s.projectId == projectId).toList();
  }

  Future<void> deleteSession({required String sessionId}) async {
    _sessions.remove(sessionId);
  }
}

class FakePrSyncService({
  final Duration? delay,
  final Object? refreshError,
  final PrRefreshOutcome refreshOutcome = PrRefreshOutcome.completed,
  final List<Duration> identityVerificationDelays = const <Duration>[],
  final FutureOr<void> Function()? refreshAction,
  VerifiedGithubLogin? verifiedGithubLogin,
  PrSourceRepository? prSource,
  PullRequestRepository? pullRequestRepository,
  SessionRepository? sessionRepository,
}) extends PrSyncService {
  final List<({Set<String> projectIds, PrRefreshPolicy refreshPolicy})> calls = [];
  VerifiedGithubLogin? verifiedGithubLogin = verifiedGithubLogin ?? VerifiedGithubLogin.tryParse(rawLogin: "octocat");
  int identityVerificationCallCount = 0;

  this
    : super(
        prSource: prSource ?? _AlwaysReadyPrSource(),
        pullRequestRepository: pullRequestRepository ?? _NoopPullRequestRepository(),
        sessionRepository: sessionRepository ?? _NoopSessionRepository(),
        clock: const Clock(),
      );

  @override
  Future<PrRefreshOutcome> triggerRefresh({
    required Set<String> projectIds,
    required PrRefreshPolicy refreshPolicy,
  }) async {
    calls.add((
      projectIds: Set<String>.from(projectIds),
      refreshPolicy: refreshPolicy,
    ));
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (refreshError case final error?) {
      throw error;
    }
    await refreshAction?.call();
    return refreshOutcome;
  }

  @override
  Future<VerifiedGithubLogin?> verifyGithubIdentity() async {
    identityVerificationCallCount++;
    final delayIndex = identityVerificationCallCount - 1;
    if (delayIndex < identityVerificationDelays.length) {
      await Future<void>.delayed(identityVerificationDelays[delayIndex]);
    }
    return verifiedGithubLogin;
  }
}

class _AlwaysReadyPrSource() implements PrSourceRepository {
  @override
  Future<bool> isGithubCliAvailable() async => true;
  @override
  Future<bool> isGithubCliAuthenticated() async => true;
  @override
  Future<VerifiedGithubLogin?> getAuthenticatedIdentity() async => VerifiedGithubLogin.tryParse(rawLogin: "octocat");
  @override
  Future<Map<String, PullRequestDirectoryTarget>> resolvePullRequestTargets({
    required Iterable<String> directories,
  }) async => {
    for (final directory in directories)
      directory: const PullRequestGithubDirectoryTarget(
        target: (githubRepositoryIdentity: "sesori-ai/test", branchName: "main"),
      ),
  };
  @override
  Future<PullRequestSelectionOutcome> selectPullRequests({
    required List<PullRequestSelectionTarget> targets,
    required VerifiedGithubLogin expectedGithubLogin,
  }) async => PullRequestSelectionCompleted(
    selections: [for (final target in targets) PullRequestTargetUnmatched(target: target)],
  );
}

class _NoopPullRequestRepository() implements PullRequestRepository {
  @override
  Future<PullRequestReplacementOutcome> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required Map<String, String> capturedRootDirectoriesBySessionId,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async => const PullRequestReplacementApplied(changed: false);

  @override
  Future<Set<String>> prepareScopedRefresh({
    required Set<String> projectIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async => const <String>{};

  @override
  Future<Set<String>> applyResolvedTargets({
    required Map<String, List<StoredSession>> sessionsByProject,
    required Map<String, PullRequestDirectoryTarget> targetsByDirectory,
  }) async => const <String>{};
}

DeletedSessionSubtree _deletedSession(String sessionId) =>
    (session: _deletedSessionInfo(sessionId), sessionIds: [sessionId]);

Session _deletedSessionInfo(String sessionId) => Session(
  branchName: null,
  id: sessionId,
  pluginId: "fake",
  projectID: "",
  directory: "",
  parentID: null,
  title: null,
  time: null,
  pullRequest: null,
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
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      projectId: projectId,
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
      lastAgent: null,
      lastAgentModel: null,
      pluginId: pluginId,
      preservePullRequestScope: false,
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

class _NoopSessionRepository() implements SessionRepository {
  @override
  Stream<SessionBindingsCommitted> get bindingCommits => const Stream.empty();

  @override
  Future<List<QueuedSessionPrompt>> getQueuedPrompts({required String sessionId}) async => const [];

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async => false;

  @override
  int captureProjectionTimestamp() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Set<String>> getStoredSessionIdsForPlugin({required String pluginId}) async => const {};

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: "fake");

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async => true;

  @override
  Future<Session?> setGeneratedSessionTitleIfAbsent({required String sessionId, required String title}) async => null;

  @override
  Future<bool> replaceGeneratedSessionBranch({
    required String sessionId,
    required String expectedBranchName,
    required String branchName,
  }) async => false;

  @override
  Future<DeletedSessionSubtree> deleteSession({
    required String sessionId,
    required BeforePersistedSessionDelete beforePersistedDelete,
  }) async {
    final deleted = _deletedSession(sessionId);
    await beforePersistedDelete(sessionIds: deleted.sessionIds);
    return deleted;
  }

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async => false;

  @override
  Future<List<String>> get persistedSessionCleanupPluginIds async => const [];

  @override
  Future<Set<String>> getTombstonedBackendSessionIdsForCleanup({required String pluginId}) async => const {};

  @override
  Future<void> deletePersistedSession({required String pluginId, required String backendSessionId}) async {}

  @override
  Future<SessionMessagesSnapshot> getSessionMessages({required String sessionId}) async => (
    messages: const <MessageWithParts>[],
    promptDefaults: null,
  );

  @override
  Future<SessionStatus?> getSessionStatus({required String sessionId}) async => null;

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async => const <ProjectActivitySummary>[];

  @override
  Future<Session> createSession({
    required String pluginId,
    required String projectId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required String? userVisibleText,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
    required bool isDedicated,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
  }) async => const Session(
    branchName: null,
    id: "",
    pluginId: "fake",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
    lastUserActivityAt: null,
  );
  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => const <Session>[];
  @override
  Future<List<Session>> enrichSessions({
    required List<Session> sessions,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => sessions;
  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async => const <Session>[];
  @override
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async => [sessionId];
  @override
  Future<Set<String>> getExistingSessionIds({required Set<String> sessionIds}) async => sessionIds;
  @override
  Future<Set<String>> getArchivedSessionIds({required Set<String> sessionIds}) async => const {};
  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async =>
      const <StoredSession>[];
  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;
  @override
  Future<String?> getProjectPath({required String projectId}) async => null;
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => null;

  @override
  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async => null;

  @override
  Future<Map<String, StoredSession>> getStoredSessionsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async => const {};

  @override
  Future<StoredSession?> updateObservedSessionProjection({
    required String pluginId,
    required int generation,
    required Session observed,
    required bool updateCatalogTitle,
    required int projectionUpdatedAt,
  }) async => null;

  @override
  Future<StoredSession?> insertObservedChild({
    required String pluginId,
    required int generation,
    required Session observed,
    required StoredSession parent,
    required int projectionUpdatedAt,
  }) async => null;

  @override
  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    throw PluginOperationException.notFound(
      operation.name,
      message: "session $sessionId was not found",
    );
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => null;

  @override
  Future<SessionStatusResponse> getSessionStatuses() async => const SessionStatusResponse(statuses: {});

  @override
  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) async {}

  @override
  Future<void> archiveStoredSession({
    required String sessionId,
    required int archivedAt,
  }) async {}

  @override
  Future<void> insertStoredSession({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? agent,
    required AgentModel? agentModel,
  }) async {}

  @override
  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {}

  @override
  Future<({String pluginId, String projectId})?> findSessionOptionsScope({required String sessionId}) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {}

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
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) async =>
      const CommandListResponse(items: []);

  @override
  Future<void> sendPrompt({
    required String promptId,
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<void> renameSession({required String sessionId, required String title}) async {}

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}

Session _sharedSessionFromPlugin(PluginSession session, String pluginId) {
  return Session(
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
    pullRequest: null,
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
  FakePullRequestRepository? pullRequestRepository,
  final AppDatabase? _persistenceDatabase,
}) implements SessionRepository {
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
  final FakePullRequestRepository _pullRequestRepository = pullRequestRepository ?? FakePullRequestRepository();
  int getSessionsCallCount = 0;
  int enrichSessionsCallCount = 0;
  ({String projectId, int? start, int? limit})? lastGetSessionsArgs;
  VerifiedGithubLogin? lastVerifiedGithubLogin;
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
  Future<Session?> setGeneratedSessionTitleIfAbsent({required String sessionId, required String title}) async {
    final stored = await _sessionDao.getSession(sessionId: sessionId);
    if (stored == null || stored.title != null) return null;
    return Session(
      branchName: stored.branchName,
      id: stored.sessionId,
      pluginId: stored.pluginId,
      projectID: stored.projectId,
      directory: stored.directory,
      parentID: stored.parentSessionId,
      title: title,
      time: SessionTime(created: stored.createdAt, updated: stored.updatedAt, archived: stored.archivedAt),
      pullRequest: null,
      promptDefaults: null,
      lastUserActivityAt: stored.lastUserMessageAt,
    );
  }

  @override
  Future<bool> replaceGeneratedSessionBranch({
    required String sessionId,
    required String expectedBranchName,
    required String branchName,
  }) async => false;

  @override
  Future<DeletedSessionSubtree> deleteSession({
    required String sessionId,
    required BeforePersistedSessionDelete beforePersistedDelete,
  }) async {
    final deleted = _deletedSession(sessionId);
    await beforePersistedDelete(sessionIds: deleted.sessionIds);
    return deleted;
  }

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
    required String? agent,
    required PromptModel? model,
    required bool isDedicated,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
  }) async => const Session(
    branchName: null,
    id: "",
    pluginId: "fake",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
    lastUserActivityAt: null,
  );

  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async {
    getSessionsCallCount++;
    lastVerifiedGithubLogin = verifiedGithubLogin;
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
    final prsBySessionId = verifiedGithubLogin == null
        ? <String, List<PullRequestDto>>{}
        : await _pullRequestRepository.getPrsBySessionIds(
            sessionIds: sessionIds,
            verifiedGithubLogin: verifiedGithubLogin,
          );
    final result = mergedSessions.map((session) {
      final prs = prsBySessionId[session.id];
      final pr = _selectBestPr(prs);
      if (pr == null) return session;
      return session.copyWith(pullRequest: pullRequestInfoFromDto(pr));
    }).toList();
    final database = _persistenceDatabase;
    if (database != null) {
      if (publicationError case final error?) throw error;
      await database.transaction(() async {
        await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
        await database.sessionDao.insertSessionsIfMissing(
          pluginId: _plugin.id,
          sessions: [
            for (final session in result)
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
    return result;
  }

  @override
  Future<List<Session>> enrichSessions({
    required List<Session> sessions,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async {
    enrichSessionsCallCount++;
    lastVerifiedGithubLogin = verifiedGithubLogin;
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);
    final prsBySessionId = verifiedGithubLogin == null
        ? <String, List<PullRequestDto>>{}
        : await _pullRequestRepository.getPrsBySessionIds(
            sessionIds: sessionIds,
            verifiedGithubLogin: verifiedGithubLogin,
          );
    final pullRequestsBySessionId = <String, PullRequestInfo>{
      for (final session in sessions)
        if (_selectBestPr(prsBySessionId[session.id]) case final pr?) session.id: pullRequestInfoFromDto(pr),
    };
    return [
      for (final session in sessions)
        session.copyWith(
          pullRequest: pullRequestsBySessionId[session.id],
          pullRequestHistory: const <PullRequestInfo>[],
        ),
    ];
  }

  static PullRequestDto? _selectBestPr(List<PullRequestDto>? prs) {
    if (prs == null || prs.isEmpty) return null;
    PullRequestDto? selected;
    for (final pr in prs) {
      if (selected == null) {
        selected = pr;
        continue;
      }
      final selectedIsOpen = selected.state == PrState.open;
      final currentIsOpen = pr.state == PrState.open;
      if (currentIsOpen && !selectedIsOpen) {
        selected = pr;
        continue;
      }
      if (currentIsOpen == selectedIsOpen && pr.prNumber > selected.prNumber) {
        selected = pr;
      }
    }
    return selected;
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
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions.map((session) => session.toStoredSession()).toList(growable: false);
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;

  @override
  Future<String?> getProjectPath({required String projectId}) async => projectPathResult;

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    return (await _sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
  }

  @override
  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async => null;

  @override
  Future<Map<String, StoredSession>> getStoredSessionsByBackendIds({
    required String pluginId,
    required List<String> backendSessionIds,
  }) async => const {};

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
  Future<StoredSession> requireRoutableStoredSession({
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
  Future<void> insertStoredSession({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    return _sessionDao.insertSession(
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      projectId: projectId,
      isDedicated: isDedicated,
      createdAt: createdAt,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      lastAgent: agent,
      lastAgentModel: agentModel,
      pluginId: pluginId,
    );
  }

  @override
  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {}

  @override
  Future<({String pluginId, String projectId})?> findSessionOptionsScope({required String sessionId}) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {
    await _plugin.abortSession(sessionId: sessionId);
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
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendCommand(
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
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendPrompt(
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
