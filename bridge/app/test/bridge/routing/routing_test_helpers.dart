import "dart:async";

import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/routing/get_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

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
  SessionMetadata? generateSessionMetadataResult;

  // ── Recorded call arguments ──────────────────────────────────────────────

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;

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
  String? lastAbortSessionId;
  String? lastReplyQuestionId;
  String? lastReplySessionId;
  List<List<String>>? lastReplyAnswers;
  String? lastRejectQuestionId;
  String? lastGetCurrentProjectProjectId;
  String? lastGenerateSessionMetadataMessage;
  String? lastGenerateSessionMetadataDirectory;

  // ── Error injection ──────────────────────────────────────────────────────

  bool throwOnHealthCheck = false;
  bool throwOnGetProjects = false;
  Object? throwOnGetProjectsError;
  Object? throwOnGetProjectError;
  bool throwOnGetSessions = false;
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
  Future<SessionMetadata?> generateSessionMetadata({
    required String firstMessage,
    required String directory,
  }) async {
    lastGenerateSessionMetadataMessage = firstMessage;
    lastGenerateSessionMetadataDirectory = directory;
    return generateSessionMetadataResult;
  }

  @override
  Future<void> dispose() async {}

  Future<void> close() => _controller.close();
}

/// Hand-written fake [SessionDao] for testing.
class FakeSessionDao implements SessionDaoLike {
  final Map<String, SessionDto> _sessions = {};

  /// Set up a session in the fake database.
  void setSession(SessionDto session) {
    _sessions[session.sessionId] = session;
  }

  @override
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
