import "dart:async";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("SessionMetadataGenerator.generate", () {
    test("happy path returns SessionMetadata", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "anthropic/claude-haiku-3"),
        sendMessageResponse: _assistantMessage(
          text: '{"title":"Fix Login Bug","branchName":"fix-login-bug"}',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "Please fix login",
        directory: "/repo",
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, equals("Fix Login Bug"));
      expect(metadata.branchName, equals("fix-login-bug"));
      expect(api.createSessionCalls, equals(1));
      expect(api.sendMessageSyncCalls, equals(1));
      expect(api.deleteSessionCalls, equals(1));
    });

    test("returns null when config has no smallModel", () async {
      final api = FakeOpenCodeApi(config: const OpenCodeConfig(smallModel: null));
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
      expect(api.createSessionCalls, equals(0));
      expect(api.sendMessageSyncCalls, equals(0));
      expect(api.deleteSessionCalls, equals(0));
    });

    test("returns null when model format has no slash", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "haiku3"),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
      expect(api.createSessionCalls, equals(0));
      expect(api.sendMessageSyncCalls, equals(0));
      expect(api.deleteSessionCalls, equals(0));
    });

    test("extracts markdown-fenced JSON", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(
          text: '```json\n{"title":"Fix","branchName":"fix"}\n```',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, equals("Fix"));
      expect(metadata.branchName, equals("fix"));
    });

    test("returns null for invalid JSON", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(text: "not-json"),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
    });

    test("returns null when title is empty", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(
          text: '{"title":"","branchName":"fix"}',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
    });

    test("returns null when branchName is empty", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(
          text: '{"title":"Fix","branchName":""}',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
    });

    test("sendMessageSync throws and still deletes ephemeral session", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageError: TimeoutException("timeout"),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
      expect(api.createSessionCalls, equals(1));
      expect(api.sendMessageSyncCalls, equals(1));
      expect(api.deleteSessionCalls, equals(1));
      expect(api.lastDeletedSessionId, equals("session-123"));
      expect(api.lastDeletedDirectory, equals("/repo"));
    });

    test("createSession throws and returns null without cleanup", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        createSessionError: StateError("failed to create"),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNull);
      expect(api.createSessionCalls, equals(1));
      expect(api.sendMessageSyncCalls, equals(0));
      expect(api.deleteSessionCalls, equals(0));
    });

    test("swallows deleteSession error and still returns metadata", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(
          text: '{"title":"Fix","branchName":"fix"}',
        ),
        deleteSessionError: StateError("delete failed"),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, equals("Fix"));
      expect(metadata.branchName, equals("fix"));
      expect(api.deleteSessionCalls, equals(1));
    });

    test("truncates long first message to 500 chars", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: _assistantMessage(
          text: '{"title":"Fix","branchName":"fix"}',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);
      final longMessage = "a" * 700;

      final metadata = await generator.generate(
        firstMessage: longMessage,
        directory: "/repo",
      );

      expect(metadata, isNotNull);
      final parts = api.lastSendMessageBody!.parts;
      expect(parts, hasLength(1));
      final sentText = parts.first["text"] as String;
      expect(sentText.length, equals(500));
      expect(sentText, equals("a" * 500));
    });
  });
}

MessageWithParts _assistantMessage({required String text}) {
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
  }) : sendMessageResponse = sendMessageResponse ?? _assistantMessage(text: '{"title":"Fix","branchName":"fix"}'),
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
