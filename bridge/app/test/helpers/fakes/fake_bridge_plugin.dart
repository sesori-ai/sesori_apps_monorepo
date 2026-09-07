import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// General-purpose native-project plugin fake shared by bridge tests.
class FakeBridgePlugin() implements NativeProjectsPluginApi {
  final List<PluginQueuedPrompt> queuedPrompts = [];
  final List<({String sessionId, String promptId})> cancelQueuedPromptCalls = [];

  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async =>
      List.unmodifiable(queuedPrompts);

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async {
    cancelQueuedPromptCalls.add((sessionId: sessionId, promptId: promptId));
    final index = queuedPrompts.indexWhere((prompt) => prompt.id == promptId);
    if (index == -1) return false;
    queuedPrompts.removeAt(index);
    return true;
  }

  final _controller = StreamController<BridgeSseEvent>.broadcast();

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

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;
  String? lastGetCommandsProjectId;
  String? lastGetMessagesSessionId;
  String? lastGetPendingQuestionsSessionId;
  String? lastGetPendingPermissionsSessionId;
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
  Object? deleteWorkspaceError;
  Completer<void>? archiveSessionCompleter;
  Completer<void>? sendCommandStarted;
  Completer<void>? sendCommandCompleter;
  Object? sendCommandError;
  Object? sendPromptError;
  int getProjectsCallCount = 0;
  int deleteWorkspaceCallCount = 0;

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
    if (throwOnGetProjectsError case final error?) throw error;
    if (throwOnGetProjects) throw Exception("getProjects error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    if (throwOnGetSessions) throw Exception("getSessions error");
    lastGetSessionsWorktree = projectId;
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
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
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
  Future<PluginProject> renameProject({required String projectId, required String name}) async {
    lastRenameProjectId = projectId;
    lastRenameProjectName = name;
    return renameProjectResult ?? const PluginProject(id: "", directory: "");
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    lastDeleteSessionId = sessionId;
    if (throwOnDeleteSessionError case final error?) throw error;
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    lastArchiveSessionId = sessionId;
    if (throwOnArchiveSessionError case final error?) throw error;
    if (archiveSessionCompleter case final completer?) await completer.future;
  }

  @override
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) async {
    deleteWorkspaceCallCount++;
    lastDeleteWorkspaceProjectId = projectId;
    lastDeleteWorkspaceWorktreePath = worktreePath;
    if (deleteWorkspaceError case final error?) throw error;
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    lastGetChildSessionsSessionId = sessionId;
    return childSessionsResult;
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => sessionStatusesResult;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    lastGetMessagesSessionId = sessionId;
    if (throwOnGetMessagesError case final error?) throw error;
    return messagesResult;
  }

  @override
  Future<void> sendPrompt({
    required String promptId,
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendPromptError case final error?) throw error;
    lastSendPromptSessionId = sessionId;
    lastSendPromptParts = parts;
    lastSendPromptVariant = variant?.id;
    lastSendPromptAgent = agent;
    lastSendPromptModel = model;
  }

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (sendCommandError case final error?) throw error;
    if (sendCommandStarted case final started? when !started.isCompleted) started.complete();
    lastSendCommandSessionId = sessionId;
    lastSendCommand = command;
    lastSendCommandArguments = arguments;
    lastSendCommandUserVisibleArguments = userVisibleArguments;
    lastSendCommandVariant = variant?.id;
    lastSendCommandAgent = agent;
    lastSendCommandModel = model;
    if (sendCommandCompleter case final completer?) await completer.future;
  }

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async {
    lastAbortSessionId = sessionId;
    return const PluginAbortAccepted(workKept: false);
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    lastAgentsProjectId = projectId;
    return agentsResult;
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    lastGetPendingQuestionsSessionId = sessionId;
    return pendingQuestionsResult;
  }

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => pendingQuestionsResult;

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async {
    lastGetPendingPermissionsSessionId = sessionId;
    return pendingPermissionsResult;
  }

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
    if (throwOnGetProjectError case final error?) throw error;
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

  Future<void> close() => _controller.close();
}
