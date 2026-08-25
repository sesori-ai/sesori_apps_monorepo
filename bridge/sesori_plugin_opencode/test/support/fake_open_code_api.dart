// ignore_for_file: annotate_overrides

import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class FakeOpenCodeApi({
  final List<Session> sessions = const [],
  final List<GlobalSession> globalSessions = const [],
  final List<Project> projects = const [],
  final List<Command> commands = const [],
  final Map<String, SessionStatus> statuses = const {},
  final List<SessionMessagesResponseItem> messages = const [],
  final Object? messagesError,
  final Session? createdSession,
  final Project? currentProject,
  final bool filterRootSessions = false,
}) implements OpenCodeApi {
  String? lastCreateDirectory;
  String? lastCreateParentSessionId;
  String? lastPromptSessionId;
  String? lastPromptDirectory;
  SendPromptBody? lastPromptBody;
  final List<SendPromptBody> promptBodies = [];
  Part? lastUpdatedPart;
  String? lastUpdatedMessageId;
  String? lastUpdatedPartId;
  String? lastDeletedMessageId;
  String? lastCommandSessionId;
  String? lastCommandDirectory;
  SendCommandBody? lastCommandBody;
  String? lastGetProjectDirectory;
  String? lastRequestedSessionId;
  String? lastRequestedDirectory;
  int updateProjectCalls = 0;

  Future<bool> healthCheck() async => true;
  Future<List<Project>> listProjects() async => projects;
  Future<List<Session>> listRootSessions() async => sessions;
  Future<List<Session>> listSessions({String? directory, required bool roots}) async =>
      roots && filterRootSessions ? sessions.where((session) => session.parentID == null).toList() : sessions;
  Future<List<Command>> listCommands({required String? directory}) async => commands;
  Future<Session> createSession({required String directory, String? parentSessionId}) async {
    lastCreateDirectory = directory;
    lastCreateParentSessionId = parentSessionId;
    return createdSession ?? _defaultCreatedSession;
  }

  Future<Session> getSession({required String sessionId, required String? directory}) async =>
      throw UnimplementedError();
  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async => throw UnimplementedError();
  Future<void> deleteSession({required String sessionId, required String? directory}) async {}
  Future<void> removeWorktree({required String directory, required String worktreePath}) async {}
  Future<SessionMessagesResponseItem?> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    required String? directory,
  }) async {
    lastPromptSessionId = sessionId;
    lastPromptDirectory = directory;
    lastPromptBody = body;
    promptBodies.add(body);
    if (!body.noReply) return null;
    return SessionMessagesResponseItem.fromJson({
      "info": {
        "id": "msg-reserved",
        "sessionID": sessionId,
        "role": "user",
        "time": const {"created": 1},
        "agent": body.agent ?? "build",
        "model": const {"providerID": "openai", "modelID": "gpt-4.1"},
      },
      "parts": [
        if (body.parts.isNotEmpty)
          {"id": "prt-reserved", "sessionID": sessionId, "messageID": "msg-reserved", "type": "text", "text": ""},
      ],
    });
  }

  Future<void> updateMessagePart({
    required String sessionId,
    required String messageId,
    required String partId,
    required Part part,
    required String? directory,
  }) async {
    lastUpdatedMessageId = messageId;
    lastUpdatedPartId = partId;
    lastUpdatedPart = part;
  }

  Future<void> deleteMessage({
    required String sessionId,
    required String messageId,
    required String? directory,
  }) async => lastDeletedMessageId = messageId;
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {
    lastCommandSessionId = sessionId;
    lastCommandDirectory = directory;
    lastCommandBody = body;
  }

  Future<void> abortSession({required String sessionId, required String? directory}) async {}
  Future<List<Agent>> listAgents({required String directory}) async => [];
  Future<List<QuestionRequest>> getPendingQuestions({required String? directory}) async => [];
  Future<List<PermissionRequest>> getPendingPermissions({required String? directory}) async => [];
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) async {}
  Future<void> replyToPermission({
    required String requestId,
    required String? directory,
    required PluginPermissionReply reply,
  }) async {}
  Future<void> rejectQuestion({required String questionId, required String? directory}) async {}
  Future<Project> getProject({required String directory}) async {
    lastGetProjectDirectory = directory;
    return currentProject ?? (throw UnimplementedError());
  }

  Future<List<Session>> getChildren({required String sessionId, required String? directory}) async => [];
  Future<List<SessionMessagesResponseItem>> getMessages({required String sessionId, required String? directory}) async {
    lastRequestedSessionId = sessionId;
    lastRequestedDirectory = directory;
    if (messagesError case final error?) throw error;
    return messages;
  }

  Future<List<GlobalSession>> listAllSessions({required String? directory, required bool roots}) async =>
      globalSessions;
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async {
    if (directory == null) return statuses;
    final ids = sessions
        .where((session) => session.directory == directory || session.directory.startsWith("$directory/"))
        .map((session) => session.id)
        .toSet();
    return Map.fromEntries(statuses.entries.where((entry) => ids.contains(entry.key)));
  }

  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(all: [], defaultValue: {}, connected: []);
  Future<ConfigProvidersResponse> listConfigProviders({required String? directory}) async =>
      const ConfigProvidersResponse(providers: [], defaultValue: {});
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required UpdateProjectBody body,
  }) async {
    updateProjectCalls += 1;
    throw UnimplementedError();
  }

  Future<Session> forkSession({required String sessionId, required String directory}) async =>
      throw UnimplementedError();
}

const _defaultCreatedSession = Session(
  slug: "slug",
  version: "v",
  id: "created",
  projectID: "global",
  directory: "/repo",
  parentID: null,
  title: "",
  time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
  summary: null,
  workspaceID: null,
  path: null,
  cost: null,
  tokens: null,
  share: null,
  agent: null,
  model: null,
  metadata: null,
  permission: null,
  revert: null,
);
