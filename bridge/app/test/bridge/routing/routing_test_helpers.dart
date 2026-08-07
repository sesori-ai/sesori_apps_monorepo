import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart" as bridge_metadata;
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_session_status_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/prompt_part_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/pull_request_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/bridge/routing/request_handler.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_bridge/src/bridge/services/pending_interaction_service.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_unseen_service.dart";
import "package:sesori_bridge/src/bridge/services/session_view_tracker.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/single_plugin_repository_test_support.dart";

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
      legacyMissingPluginId: plugin.id,
    ),
  );
}

/// Convenience factory for [RelayRequest] instances in tests.
RelayRequest makeRequest(
  String method,
  String path, {
  Map<String, String> headers = const {},
  String? body,
}) =>
    RelayMessage.request(
          id: "test-id",
          method: method,
          path: path,
          headers: headers,
          body: body,
        )
        as RelayRequest;

extension RequestHandlerTestMatching on RequestHandlerBase {
  bool canHandle(RelayRequest request) {
    final method = HttpMethod.parseExternal(rawMethod: request.method);
    if (method == null) return false;
    return matches(requestMethod: method, target: Uri.parse(request.path));
  }

  ({
    Map<String, String> pathParams,
    Map<String, String> queryParams,
    String? fragment,
  })
  extractParams(RelayRequest request) => extractTargetParams(target: Uri.parse(request.path));
}

/// Hand-written fake [BridgePluginApi] used across routing handler tests.
class FakeBridgePlugin implements NativeProjectsPluginApi {
  final _controller = StreamController<BridgeSseEvent>.broadcast();

  // ── Configurable return values ───────────────────────────────────────────

  List<PluginProject> projectsResult = [];
  List<PluginSession> sessionsResult = [];
  List<PluginCommand> commandsResult = [];
  List<PluginMessageWithParts> messagesResult = [];
  PluginProvidersResult providersResult = const PluginProvidersResult(providers: []);
  PluginSession? createSessionResult;
  PluginSession? renameSessionResult;
  PluginProject? renameProjectResult;
  List<PluginSession> childSessionsResult = [];
  Map<String, PluginSessionStatus> sessionStatusesResult = {};
  List<PluginAgent> agentsResult = [];
  String? lastAgentsProjectId;
  List<PluginPendingQuestion> pendingQuestionsResult = [];
  List<PluginPendingPermission> pendingPermissionsResult = [];
  PluginProject? currentProjectResult;

  // ── Recorded call arguments ──────────────────────────────────────────────

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;
  String? lastGetCommandsProjectId;

  String? lastGetMessagesSessionId;

  String? lastGetProvidersProjectId;
  String? lastCreateSessionDirectory;
  String? lastCreateSessionParentId;
  String? lastCreateSessionProjectId;
  List<PluginPromptPart>? lastCreateSessionParts;
  String? lastCreateSessionUserVisibleText;
  String? lastCreateSessionVariant;
  String? lastCreateSessionAgent;
  ({String providerID, String modelID})? lastCreateSessionModel;
  String? lastRenameSessionId;
  String? lastRenameSessionTitle;
  String? lastRenameProjectId;
  String? lastRenameProjectName;
  String? lastDeleteSessionId;
  String? lastArchiveSessionId;
  String? lastDeleteWorkspaceProjectId;
  String? lastDeleteWorkspaceWorktreePath;
  String? lastGetChildSessionsSessionId;
  String? lastSendPromptSessionId;
  List<PluginPromptPart>? lastSendPromptParts;
  String? lastSendPromptVariant;
  String? lastSendPromptAgent;
  ({String providerID, String modelID})? lastSendPromptModel;
  String? lastSendCommandSessionId;
  String? lastSendCommand;
  String? lastSendCommandArguments;
  String? lastSendCommandUserVisibleArguments;
  String? lastSendCommandVariant;
  String? lastSendCommandAgent;
  ({String providerID, String modelID})? lastSendCommandModel;
  String? lastAbortSessionId;
  String? lastReplyQuestionId;
  String? lastReplySessionId;
  List<List<String>>? lastReplyAnswers;
  String? lastRejectQuestionId;
  String? lastRejectSessionId;
  String? lastGetCurrentProjectProjectId;
  String? lastReplyToPermissionRequestId;
  String? lastReplyToPermissionSessionId;
  PluginPermissionReply? lastReplyToPermissionReply;

  // ── Error injection ──────────────────────────────────────────────────────

  bool throwOnHealthCheck = false;
  bool healthCheckResult = true;
  int healthCheckCallCount = 0;
  bool throwOnGetProjects = false;
  Object? throwOnGetProjectsError;
  Object? throwOnGetProjectError;
  bool throwOnGetSessions = false;
  Object? throwOnGetMessagesError;
  Object? throwOnDeleteSessionError;
  Object? throwOnArchiveSessionError;
  Completer<void>? archiveSessionCompleter;
  Completer<void>? sendCommandCompleter;
  int getProjectsCallCount = 0;

  // ── BridgePlugin implementation ──────────────────────────────────────────

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  void emitEvent(BridgeSseEvent event) => _controller.add(event);

  Future<void> closeEvents() => _controller.close();

  @override
  Future<bool> healthCheck() async {
    healthCheckCallCount++;
    if (throwOnHealthCheck) throw Exception("healthCheck error");
    return healthCheckResult;
  }

  @override
  Future<List<PluginProject>> getProjects() async {
    getProjectsCallCount++;
    if (throwOnGetProjectsError case final error?) {
      throw error;
    }
    if (throwOnGetProjects) throw Exception("getProjects error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async {
    if (throwOnGetSessions) throw Exception("getSessions error");
    lastGetSessionsWorktree = worktree;
    lastGetSessionsStart = start;
    lastGetSessionsLimit = limit;
    return sessionsResult;
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    lastGetCommandsProjectId = projectId;
    return commandsResult;
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

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
    lastCreateSessionDirectory = directory;
    lastCreateSessionParentId = parentSessionId;
    lastCreateSessionProjectId = directory;
    lastCreateSessionParts = parts;
    lastCreateSessionUserVisibleText = userVisibleText;
    lastCreateSessionVariant = variant?.id;
    lastCreateSessionAgent = agent;
    lastCreateSessionModel = model;
    return createSessionResult ??
        const PluginSession(
          id: "",
          projectID: "",
          directory: "",
          parentID: null,
          title: null,
          time: null,
        );
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    lastRenameSessionId = sessionId;
    lastRenameSessionTitle = title;
    return renameSessionResult ??
        const PluginSession(
          id: "",
          projectID: "",
          directory: "",
          parentID: null,
          title: null,
          time: null,
        );
  }

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    lastRenameProjectId = projectId;
    lastRenameProjectName = name;
    return renameProjectResult ?? const PluginProject(id: "", directory: "");
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    lastDeleteSessionId = sessionId;
    if (throwOnDeleteSessionError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    lastArchiveSessionId = sessionId;
    if (throwOnArchiveSessionError case final error?) {
      throw error;
    }
    if (archiveSessionCompleter case final completer?) {
      await completer.future;
    }
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    lastDeleteWorkspaceProjectId = projectId;
    lastDeleteWorkspaceWorktreePath = worktreePath;
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    lastGetChildSessionsSessionId = sessionId;
    return childSessionsResult;
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => sessionStatusesResult;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async {
    lastGetMessagesSessionId = sessionId;
    if (throwOnGetMessagesError case final error?) {
      throw error;
    }
    return messagesResult;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastSendPromptSessionId = sessionId;
    lastSendPromptParts = parts;
    lastSendPromptVariant = variant?.id;
    lastSendPromptAgent = agent;
    lastSendPromptModel = model;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastSendCommandSessionId = sessionId;
    lastSendCommand = command;
    lastSendCommandArguments = arguments;
    lastSendCommandUserVisibleArguments = userVisibleArguments;
    lastSendCommandVariant = variant?.id;
    lastSendCommandAgent = agent;
    lastSendCommandModel = model;
    if (sendCommandCompleter case final completer?) {
      await completer.future;
    }
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    lastAbortSessionId = sessionId;
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    lastAgentsProjectId = projectId;
    return agentsResult;
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => pendingQuestionsResult;

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => pendingQuestionsResult;

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async =>
      pendingPermissionsResult;

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    lastReplyQuestionId = questionId;
    lastReplySessionId = sessionId;
    lastReplyAnswers = answers;
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    lastRejectQuestionId = questionId;
    lastRejectSessionId = sessionId;
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    lastReplyToPermissionRequestId = requestId;
    lastReplyToPermissionSessionId = sessionId;
    lastReplyToPermissionReply = reply;
  }

  @override
  Future<PluginProject> getProject(String projectId) async {
    if (throwOnGetProjectError case final error?) {
      throw error;
    }
    lastGetCurrentProjectProjectId = projectId;
    return currentProjectResult ?? const PluginProject(id: "", directory: "");
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    lastGetProvidersProjectId = projectId;
    return providersResult;
  }

  @override
  Future<void> dispose() async {}

  Future<void> close() => _controller.close();
}

/// Hand-written fake [SessionDao] for testing.
class FakeSessionDao {
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

/// Hand-written fake [MetadataService] for testing.
class FakeMetadataService implements MetadataService {
  bridge_metadata.SessionMetadata? generateResult;
  String? lastGenerateMessage;

  @override
  Future<bridge_metadata.SessionMetadata?> generate({required String firstMessage}) async {
    lastGenerateMessage = firstMessage;
    return generateResult;
  }
}

class FakePullRequestRepository implements PullRequestRepository {
  final Map<String, List<PullRequestDto>> _prsBySessionId = <String, List<PullRequestDto>>{};
  final Map<String, PullRequestDto> _prsByPrimaryKey = <String, PullRequestDto>{};

  FakePullRequestRepository();

  void setPr({required String sessionId, required PullRequestDto pullRequest}) {
    _prsBySessionId.putIfAbsent(sessionId, () => <PullRequestDto>[]).add(pullRequest);
    _prsByPrimaryKey[_key(
          projectId: pullRequest.projectId,
          githubRepositoryIdentity: pullRequest.githubRepositoryIdentity,
          prNumber: pullRequest.prNumber,
        )] =
        pullRequest;
  }

  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({
    required List<String> sessionIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async {
    return <String, List<PullRequestDto>>{
      for (final sessionId in sessionIds)
        if (_prsBySessionId[sessionId]?.where((pr) => pr.githubLogin == verifiedGithubLogin.login).toList()
            case final matching? when matching.isNotEmpty)
          sessionId: matching,
    };
  }

  @override
  Future<PullRequestReplacementOutcome> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required Map<String, String> capturedRootDirectoriesBySessionId,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async {
    _prsByPrimaryKey.removeWhere((_, pullRequest) => pullRequest.projectId == projectId);
    for (final selection in targetSelections) {
      if (selection is! PullRequestTargetSelected) continue;
      final pullRequest = selection;
      final record = PullRequestDto(
        projectId: projectId,
        githubRepositoryIdentity: pullRequest.target.githubRepositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        prNumber: pullRequest.number,
        branchName: pullRequest.target.branchName,
        url: pullRequest.url,
        title: pullRequest.title,
        state: pullRequest.state,
        mergeableStatus: pullRequest.mergeableStatus,
        reviewDecision: pullRequest.reviewDecision,
        checkStatus: pullRequest.checkStatus,
        lastCheckedAt: lastCheckedAt,
        createdAt: pullRequest.createdAt.millisecondsSinceEpoch,
      );
      _prsByPrimaryKey[_key(
            projectId: record.projectId,
            githubRepositoryIdentity: record.githubRepositoryIdentity,
            prNumber: record.prNumber,
          )] =
          record;
    }
    return const PullRequestReplacementApplied(changed: true);
  }

  String _key({
    required String projectId,
    required String githubRepositoryIdentity,
    required int prNumber,
  }) {
    return "$projectId::$githubRepositoryIdentity::$prNumber";
  }

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

class FakePrSyncService extends PrSyncService {
  final List<({Set<String> projectIds, PrRefreshPolicy refreshPolicy})> calls = [];
  final Duration? delay;
  final Object? refreshError;
  final PrRefreshOutcome refreshOutcome;
  final List<Duration> identityVerificationDelays;
  final FutureOr<void> Function()? refreshAction;
  VerifiedGithubLogin? verifiedGithubLogin;
  int identityVerificationCallCount = 0;

  FakePrSyncService({
    this.delay,
    this.refreshError,
    this.refreshOutcome = PrRefreshOutcome.completed,
    this.identityVerificationDelays = const <Duration>[],
    this.refreshAction,
    VerifiedGithubLogin? verifiedGithubLogin,
    PrSourceRepository? prSource,
    PullRequestRepository? pullRequestRepository,
    SessionRepository? sessionRepository,
  }) : verifiedGithubLogin = verifiedGithubLogin ?? VerifiedGithubLogin.tryParse(rawLogin: "octocat"),
       super(
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

class _AlwaysReadyPrSource implements PrSourceRepository {
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

class _NoopPullRequestRepository implements PullRequestRepository {
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

Session _deletedSession(String sessionId) => Session(
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

class _NoopSessionRepository implements SessionRepository {
  @override
  Stream<SessionBindingsCommitted> get bindingCommits => const Stream.empty();

  @override
  int captureProjectionTimestamp() => DateTime.now().millisecondsSinceEpoch;

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
  Future<Session> deleteSession({required String sessionId}) async => _deletedSession(sessionId);

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async => false;

  @override
  Future<List<String>> get persistedSessionCleanupPluginIds async => const [];

  @override
  Future<Set<String>> getTombstonedBackendSessionIdsForCleanup({required String pluginId}) async => const {};

  @override
  Future<void> deletePersistedSession({required String pluginId, required String backendSessionId}) async {}

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async => const <MessageWithParts>[];

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
  );
  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => const <Session>[];
  @override
  Future<Session> enrichSession({
    required Session session,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => session;
  @override
  Future<Session> enrichPluginSession({required String pluginId, required PluginSession pluginSession}) async =>
      pluginSession.toSharedSession(pluginId: pluginId);
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
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;

  @override
  Future<Session?> getSessionForProject({
    required String projectId,
    required String sessionId,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
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
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
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
  );

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}

/// Test-friendly [SessionRepository] that delegates to a [FakeBridgePlugin]
/// and [FakeSessionDao], so handler tests can configure plugin/DAO behaviour
/// without needing real implementations.
class FakeSessionRepository implements SessionRepository {
  @override
  Stream<SessionBindingsCommitted> get bindingCommits => const Stream.empty();

  @override
  int captureProjectionTimestamp() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<void> dispose() async {}

  final FakeBridgePlugin _plugin;
  final FakeSessionDao _sessionDao;
  final FakePullRequestRepository _pullRequestRepository;
  final AppDatabase? _persistenceDatabase;
  int getSessionsCallCount = 0;
  int enrichSessionsCallCount = 0;
  ({String projectId, int? start, int? limit})? lastGetSessionsArgs;
  VerifiedGithubLogin? lastVerifiedGithubLogin;
  String? projectPathResult;
  Object? publicationError;

  FakeSessionRepository({
    required FakeBridgePlugin plugin,
    FakeSessionDao? sessionDao,
    FakePullRequestRepository? pullRequestRepository,
    AppDatabase? persistenceDatabase,
  }) : _plugin = plugin,
       _sessionDao = sessionDao ?? FakeSessionDao(),
       _pullRequestRepository = pullRequestRepository ?? FakePullRequestRepository(),
       _persistenceDatabase = persistenceDatabase;

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: _plugin.id);

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    final pluginMessages = await _plugin.getSessionMessages(sessionId);
    return pluginMessages.toSharedMessageWithParts(sessionId: sessionId);
  }

  /// Recorded setSessionTitleIfStored calls (sessionId → title).
  final List<({String sessionId, String? title})> recordedTitles = [];

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    recordedTitles.add((sessionId: sessionId, title: title));
    return true;
  }

  @override
  Future<Session> deleteSession({required String sessionId}) async => _deletedSession(sessionId);

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
      projectId,
      start: start,
      limit: limit,
    );
    final sessions = pluginSessions.map((s) => s.toSharedSession(pluginId: _plugin.id)).toList();
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
  Future<Session> enrichSession({
    required Session session,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async {
    final sessions = await enrichSessions(
      sessions: [session],
      verifiedGithubLogin: verifiedGithubLogin,
    );
    return sessions.single;
  }

  @override
  Future<Session> enrichPluginSession({required String pluginId, required PluginSession pluginSession}) async {
    return enrichSession(
      session: pluginSession.toSharedSession(pluginId: pluginId),
      verifiedGithubLogin: null,
    );
  }

  @override
  Future<List<Session>> enrichSessions({
    required List<Session> sessions,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async {
    enrichSessionsCallCount++;
    lastVerifiedGithubLogin = verifiedGithubLogin;
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);
    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);
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
    return enrichSharedSessions(
      sessions: [
        for (final session in sessions)
          session.copyWith(
            pullRequest: null,
            pullRequestHistory: const <PullRequestInfo>[],
          ),
      ],
      storedSessionsById: dbSessions,
      pullRequestsBySessionId: pullRequestsBySessionId,
      unseenCalculator: const SessionUnseenCalculator(),
      adoptStoredProjectId: false,
    );
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
    return pluginSessions.map((s) => s.toSharedSession(pluginId: _plugin.id)).toList();
  }

  @override
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async {
    final stored = await _sessionDao.getSession(sessionId: sessionId);
    return stored == null ? const [] : [sessionId];
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
  }) async => getStoredSessionByBackendId(pluginId: pluginId, backendSessionId: observed.id);

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
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;

  @override
  Future<Session?> getSessionForProject({
    required String projectId,
    required String sessionId,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async {
    final sessions = await getSessionsForProject(
      projectId: projectId,
      start: null,
      limit: null,
      verifiedGithubLogin: verifiedGithubLogin,
    );
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    await _plugin.abortSession(sessionId: sessionId);
  }

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendCommand(
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
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendPrompt(
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
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
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
  );

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}
