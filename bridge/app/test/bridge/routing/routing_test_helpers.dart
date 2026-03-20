import "dart:async";

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
  PluginSession? updateSessionResult;
  List<PluginSession> childSessionsResult = [];
  Map<String, PluginSessionStatus> sessionStatusesResult = {};
  List<PluginAgent> agentsResult = [];
  List<PluginPendingQuestion> pendingQuestionsResult = [];
  PluginProject? currentProjectResult;

  // ── Recorded call arguments ──────────────────────────────────────────────

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;

  String? lastGetMessagesSessionId;

  bool? lastGetProvidersConnectedOnly;
  String? lastCreateSessionWorktree;
  String? lastUpdateSessionId;
  int? lastUpdateSessionArchivedAt;
  String? lastDeleteSessionId;
  String? lastGetChildSessionsSessionId;
  String? lastSendPromptSessionId;
  List<PluginPromptPart>? lastSendPromptParts;
  String? lastSendPromptAgent;
  String? lastSendPromptProviderID;
  String? lastSendPromptModelID;
  String? lastAbortSessionId;
  String? lastReplyQuestionId;
  List<List<String>>? lastReplyAnswers;
  String? lastRejectQuestionId;
  String? lastGetCurrentProjectWorktree;

  // ── Error injection ──────────────────────────────────────────────────────

  bool throwOnHealthCheck = false;
  bool throwOnGetProjects = false;
  bool throwOnGetSessions = false;

  // ── BridgePlugin implementation ──────────────────────────────────────────

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  @override
  Future<String> healthCheck() async {
    if (throwOnHealthCheck) throw Exception("healthCheck error");
    return '{"status":"ok"}';
  }

  @override
  Future<List<PluginProject>> getProjects() async {
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
  Future<PluginSession> createSession(String worktree) async {
    lastCreateSessionWorktree = worktree;
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
  Future<PluginSession> updateSessionArchiveStatus(
    String sessionId, {
    required int? archivedAt,
  }) async {
    lastUpdateSessionId = sessionId;
    lastUpdateSessionArchivedAt = archivedAt;
    return updateSessionResult ??
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
  Future<void> deleteSession(String sessionId) async {
    lastDeleteSessionId = sessionId;
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
    String? agent,
    String? providerID,
    String? modelID,
  }) async {
    lastSendPromptSessionId = sessionId;
    lastSendPromptParts = parts;
    lastSendPromptAgent = agent;
    lastSendPromptProviderID = providerID;
    lastSendPromptModelID = modelID;
  }

  @override
  Future<void> abortSession(String sessionId) async {
    lastAbortSessionId = sessionId;
  }

  @override
  Future<List<PluginAgent>> getAgents() async => agentsResult;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions() async => pendingQuestionsResult;

  @override
  Future<void> replyToQuestion(
    String questionId, {
    required List<List<String>> answers,
  }) async {
    lastReplyQuestionId = questionId;
    lastReplyAnswers = answers;
  }

  @override
  Future<void> rejectQuestion(String questionId) async {
    lastRejectQuestionId = questionId;
  }

  @override
  Future<PluginProject> getCurrentProject(String worktree) async {
    lastGetCurrentProjectWorktree = worktree;
    return currentProjectResult ?? const PluginProject(id: "", worktree: "");
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
