import "package:opencode_plugin/opencode_plugin.dart";

MessageWithParts assistantMessage({required String text}) {
  return MessageWithParts(
    info: const Message(role: "assistant", id: "msg-1", sessionID: "session-123"),
    parts: [
      MessagePart(
        id: "part-1",
        sessionID: "session-123",
        messageID: "msg-1",
        type: "text",
        text: text,
      ),
    ],
  );
}

class FakeOpenCodeApi extends OpenCodeApi {
  OpenCodeConfig config;
  Object? getConfigError;
  Session createSessionResult;
  Object? createSessionError;
  MessageWithParts sendMessageResponse;
  Object? sendMessageError;
  Object? deleteSessionError;

  int createSessionCalls = 0;
  int sendMessageSyncCalls = 0;
  int deleteSessionCalls = 0;

  String? lastDeletedSessionId;
  String? lastDeletedDirectory;
  SendMessageSyncBody? lastSendMessageBody;

  FakeOpenCodeApi({
    this.config = const OpenCodeConfig(),
    this.getConfigError,
    this.createSessionResult = const Session(
      id: "session-123",
      projectID: "project-1",
      directory: "/repo",
    ),
    this.createSessionError,
    MessageWithParts? sendMessageResponse,
    this.sendMessageError,
    this.deleteSessionError,
  }) : sendMessageResponse = sendMessageResponse ?? assistantMessage(text: '{"title":"Fix","branchName":"fix"}'),
       super(serverURL: "http://fake", password: null);

  @override
  Future<OpenCodeConfig> getConfig() async {
    if (getConfigError != null) {
      throw getConfigError!;
    }
    return config;
  }

  @override
  Future<Session> createSession({
    required String directory,
    String? parentSessionId,
  }) async {
    createSessionCalls += 1;
    if (createSessionError != null) {
      throw createSessionError!;
    }
    return createSessionResult;
  }

  @override
  Future<MessageWithParts> sendMessageSync({
    required String sessionId,
    required String directory,
    required SendMessageSyncBody body,
  }) async {
    sendMessageSyncCalls += 1;
    lastSendMessageBody = body;
    if (sendMessageError != null) {
      throw sendMessageError!;
    }
    return sendMessageResponse;
  }

  @override
  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) async {
    deleteSessionCalls += 1;
    lastDeletedSessionId = sessionId;
    lastDeletedDirectory = directory;
    if (deleteSessionError != null) {
      throw deleteSessionError!;
    }
  }
}
