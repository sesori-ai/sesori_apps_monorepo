import "dart:async";

import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart" as bridge_metadata;
import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_command_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/prompt_part_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/pull_request_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;

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

/// Hand-written fake [BridgePlugin] used across routing handler tests.
class FakeBridgePlugin implements BridgePlugin {
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
  List<PluginPendingQuestion> pendingQuestionsResult = [];
  PluginProject? currentProjectResult;

  // ── Recorded call arguments ──────────────────────────────────────────────

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;
  String? lastGetCommandsProjectId;

  String? lastGetMessagesSessionId;

  bool? lastGetProvidersConnectedOnly;
  String? lastCreateSessionDirectory;
  String? lastCreateSessionParentId;
  String? lastCreateSessionProjectId;
  List<PluginPromptPart>? lastCreateSessionParts;
  String? lastCreateSessionAgent;
  ({String providerID, String modelID})? lastCreateSessionModel;
  String? lastRenameSessionId;
  String? lastRenameSessionTitle;
  String? lastRenameProjectId;
  String? lastRenameProjectName;
  String? lastDeleteSessionId;
  String? lastArchiveSessionId;
  String? lastGetChildSessionsSessionId;
  String? lastSendPromptSessionId;
  List<PluginPromptPart>? lastSendPromptParts;
  String? lastSendPromptAgent;
  ({String providerID, String modelID})? lastSendPromptModel;
  String? lastSendCommandSessionId;
  String? lastSendCommand;
  String? lastSendCommandArguments;
  String? lastSendCommandAgent;
  ({String providerID, String modelID})? lastSendCommandModel;
  String? lastAbortSessionId;
  String? lastReplyQuestionId;
  String? lastReplySessionId;
  List<List<String>>? lastReplyAnswers;
  String? lastRejectQuestionId;
  String? lastGetCurrentProjectProjectId;
  String? lastReplyToPermissionRequestId;
  String? lastReplyToPermissionSessionId;
  PluginPermissionReply? lastReplyToPermissionReply;

  // ── Error injection ──────────────────────────────────────────────────────

  bool throwOnHealthCheck = false;
  bool throwOnGetProjects = false;
  Object? throwOnGetProjectsError;
  Object? throwOnGetProjectError;
  bool throwOnGetSessions = false;
  Object? throwOnGetMessagesError;
  Object? throwOnDeleteSessionError;
  Object? throwOnArchiveSessionError;
  Completer<void>? archiveSessionCompleter;

  // ── BridgePlugin implementation ──────────────────────────────────────────

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  @override
  Future<bool> healthCheck() async {
    if (throwOnHealthCheck) throw Exception("healthCheck error");
    return true;
  }

  @override
  Future<List<PluginProject>> getProjects() async {
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
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastCreateSessionDirectory = directory;
    lastCreateSessionParentId = parentSessionId;
    lastCreateSessionProjectId = directory;
    lastCreateSessionParts = parts;
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
          summary: null,
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
          summary: null,
        );
  }

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    lastRenameProjectId = projectId;
    lastRenameProjectName = name;
    return renameProjectResult ?? const PluginProject(id: "");
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
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastSendPromptSessionId = sessionId;
    lastSendPromptParts = parts;
    lastSendPromptAgent = agent;
    lastSendPromptModel = model;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastSendCommandSessionId = sessionId;
    lastSendCommand = command;
    lastSendCommandArguments = arguments;
    lastSendCommandAgent = agent;
    lastSendCommandModel = model;
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    lastAbortSessionId = sessionId;
  }

  @override
  Future<List<PluginAgent>> getAgents() async => agentsResult;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => pendingQuestionsResult;

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => pendingQuestionsResult;

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
  Future<void> rejectQuestion(String questionId) async {
    lastRejectQuestionId = questionId;
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
    return currentProjectResult ?? const PluginProject(id: "");
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    lastGetProvidersConnectedOnly = connectedOnly;
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
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
  }) async {
    _sessions[sessionId] = SessionDto(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
      isDedicated: isDedicated,
      archivedAt: null,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      createdAt: createdAt,
    );
  }

  Future<SessionDto?> getSession({required String sessionId}) async => _sessions[sessionId];

  Future<void> setArchived({required String sessionId, required int archivedAt}) async {
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;
      _sessions[sessionId] = session.copyWith(archivedAt: archivedAt);
    }
  }

  Future<void> clearArchived({required String sessionId}) async {
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;
      _sessions[sessionId] = session.copyWith(archivedAt: null);
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
    _prsByPrimaryKey[_key(projectId: pullRequest.projectId, prNumber: pullRequest.prNumber)] = pullRequest;
  }

  @override
  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return <String, List<PullRequestDto>>{
      for (final sessionId in sessionIds)
        if (_prsBySessionId.containsKey(sessionId)) sessionId: _prsBySessionId[sessionId]!,
    };
  }

  Future<List<PullRequestDto>> getActivePrsByProjectId({required String projectId}) async {
    return _prsByPrimaryKey.values.where((pr) => pr.projectId == projectId && pr.state == PrState.open).toList();
  }

  @override
  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) {
    return getActivePrsByProjectId(projectId: projectId);
  }

  @override
  Future<void> upsertPullRequest({required PullRequestDto record}) async {
    _prsByPrimaryKey[_key(projectId: record.projectId, prNumber: record.prNumber)] = record;
  }

  @override
  Future<void> upsertFromGhPr({
    required String projectId,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) {
    return upsertPullRequest(
      record: PullRequestDto(
        projectId: projectId,
        prNumber: pr.number,
        branchName: pr.headRefName,
        url: pr.url,
        title: pr.title,
        state: pr.state,
        mergeableStatus: pr.mergeable,
        reviewDecision: pr.reviewDecision,
        checkStatus: pr.statusCheckRollup,
        lastCheckedAt: lastCheckedAt,
        createdAt: createdAt,
      ),
    );
  }

  @override
  bool hasChangedFromExisting({required PullRequestDto? existing, required GhPullRequest pr}) {
    if (existing == null) return true;
    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.branchName != pr.headRefName ||
        existing.state != pr.state ||
        existing.mergeableStatus != pr.mergeable ||
        existing.reviewDecision != pr.reviewDecision ||
        existing.checkStatus != pr.statusCheckRollup;
  }

  String _key({required String projectId, required int prNumber}) {
    return "$projectId::$prNumber";
  }

  @override
  Future<void> deletePr({required String projectId, required int prNumber}) async {
    _prsByPrimaryKey.remove(_key(projectId: projectId, prNumber: prNumber));
    _prsBySessionId.updateAll(
      (_, List<PullRequestDto> list) =>
          list.where((pr) => !(pr.projectId == projectId && pr.prNumber == prNumber)).toList(),
    );
  }
}

class FakePrSyncService extends PrSyncService {
  final List<({String projectId, String projectPath})> calls = <({String projectId, String projectPath})>[];

  FakePrSyncService({
    PrSourceRepository? prSource,
    PullRequestRepository? pullRequestRepository,
    SessionRepository? sessionRepository,
  }) : super(
         prSource: prSource ?? _AlwaysReadyPrSource(),
         pullRequestRepository: pullRequestRepository ?? _NoopPullRequestRepository(),
         sessionRepository: sessionRepository ?? _NoopSessionRepository(),
       );

  @override
  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {
    calls.add((projectId: projectId, projectPath: projectPath));
  }
}

class FakeSessionPersistenceService extends SessionPersistenceService {
  final List<String> ensuredProjectIds = <String>[];
  final List<({String projectId, List<Session> sessions})> persistedCalls =
      <({String projectId, List<Session> sessions})>[];

  FakeSessionPersistenceService()
    : super(
        projectsDao: _unsupportedProjectsDao(),
        sessionDao: _unsupportedSessionDao(),
        db: _unsupportedDatabase(),
      );

  static ProjectsDao _unsupportedProjectsDao() => throw UnimplementedError();

  static SessionDao _unsupportedSessionDao() => throw UnimplementedError();

  static AppDatabase _unsupportedDatabase() => throw UnimplementedError();

  @override
  Future<void> ensureProject({required String projectId}) async {
    ensuredProjectIds.add(projectId);
  }

  @override
  Future<void> persistSessionsForProject({
    required String projectId,
    required List<Session> sessions,
  }) async {
    persistedCalls.add((projectId: projectId, sessions: sessions));
  }
}

class _AlwaysReadyPrSource implements PrSourceRepository {
  @override
  Future<bool> isGithubCliAvailable() async => true;
  @override
  Future<bool> isGithubCliAuthenticated() async => true;
  @override
  Future<bool> hasGitHubRemote({required String projectPath}) async => true;
  @override
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async => const <GhPullRequest>[];
  @override
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) async =>
      throw StateError("getPrByNumber should not be called");
}

class _NoopPullRequestRepository implements PullRequestRepository {
  @override
  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) async =>
      const <PullRequestDto>[];

  @override
  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return <String, List<PullRequestDto>>{};
  }

  @override
  bool hasChangedFromExisting({required PullRequestDto? existing, required GhPullRequest pr}) => true;

  @override
  Future<void> upsertFromGhPr({
    required String projectId,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) async {}

  @override
  Future<void> deletePr({required String projectId, required int prNumber}) async {}

  @override
  Future<void> upsertPullRequest({required PullRequestDto record}) async {}
}

class _NoopSessionRepository implements SessionRepository {
  @override
  Future<Session> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
  }) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
  );
  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => const <Session>[];
  @override
  Future<Session> enrichSession({required Session session}) async => session;
  @override
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async => pluginSession.toSharedSession();
  @override
  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) async => Session.fromJson(sessionJson);
  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async => sessions;
  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async => const <Session>[];
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
  Future<SessionDto?> getStoredSession({required String sessionId}) async => null;

  @override
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;

  @override
  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<CommandListResponse> getCommands({required String? projectId}) async => const CommandListResponse(items: []);

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
  );
}

/// Test-friendly [SessionRepository] that delegates to a [FakeBridgePlugin]
/// and [FakeSessionDao], so handler tests can configure plugin/DAO behaviour
/// without needing real implementations.
class FakeSessionRepository implements SessionRepository {
  final FakeBridgePlugin _plugin;
  final FakeSessionDao _sessionDao;
  final FakePullRequestRepository _pullRequestRepository;
  int getSessionsCallCount = 0;
  ({String projectId, int? start, int? limit})? lastGetSessionsArgs;

  FakeSessionRepository({
    required FakeBridgePlugin plugin,
    FakeSessionDao? sessionDao,
    FakePullRequestRepository? pullRequestRepository,
  }) : _plugin = plugin,
       _sessionDao = sessionDao ?? FakeSessionDao(),
       _pullRequestRepository = pullRequestRepository ?? FakePullRequestRepository();

  @override
  Future<Session> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
  }) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
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
      projectId,
      start: start,
      limit: limit,
    );
    final sessions = pluginSessions.map((s) => s.toSharedSession()).toList();
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
    final prsBySessionId = await _pullRequestRepository.getPrsBySessionIds(sessionIds: sessionIds);
    return mergedSessions.map((session) {
      final prs = prsBySessionId[session.id];
      final pr = _selectBestPr(prs);
      if (pr == null) return session;
      return session.copyWith(pullRequest: pullRequestInfoFromDto(pr));
    }).toList();
  }

  @override
  Future<Session> enrichSession({required Session session}) async {
    final sessions = await enrichSessions(sessions: [session]);
    return sessions.single;
  }

  @override
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async {
    return enrichSession(session: pluginSession.toSharedSession());
  }

  @override
  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) async {
    return enrichSession(session: Session.fromJson(sessionJson));
  }

  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async {
    final sessionIds = sessions.map((session) => session.id).toList(growable: false);
    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);
    final prsBySessionId = await _pullRequestRepository.getPrsBySessionIds(sessionIds: sessionIds);
    final pullRequestsBySessionId = <String, PullRequestInfo>{
      for (final session in sessions)
        if (_selectBestPr(prsBySessionId[session.id]) case final pr?) session.id: pullRequestInfoFromDto(pr),
    };
    return enrichSharedSessions(
      sessions: sessions,
      storedSessionsById: dbSessions,
      pullRequestsBySessionId: pullRequestsBySessionId,
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
    return pluginSessions.map((s) => s.toSharedSession()).toList();
  }

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    final sessions = await _sessionDao.getSessionsByProject(projectId: projectId);
    return sessions.map((s) => StoredSession(id: s.sessionId, branchName: s.branchName)).toList(growable: false);
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;

  @override
  Future<String?> getProjectPath({required String projectId}) async {
    try {
      final project = await _plugin.getProject(projectId);
      if (project.id.isEmpty) return null;
      return project.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SessionDto?> getStoredSession({required String sessionId}) async {
    return _sessionDao.getSession(sessionId: sessionId);
  }

  @override
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;

  @override
  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async {
    final sessions = await getSessionsForProject(projectId: projectId, start: null, limit: null);
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
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendCommand(
      sessionId: sessionId,
      command: command,
      arguments: arguments,
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  @override
  Future<CommandListResponse> getCommands({required String? projectId}) async {
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
    required String? agent,
    required PromptModel? model,
  }) async {
    await _plugin.sendPrompt(
      sessionId: sessionId,
      parts: parts.map((part) => part.toPlugin()).toList(growable: false),
      agent: agent,
      model: switch (model) {
        PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
        null => null,
      },
    );
  }

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
    pullRequest: null,
  );
}
