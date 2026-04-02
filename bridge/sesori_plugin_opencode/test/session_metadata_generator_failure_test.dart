import "dart:async";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

import "session_metadata_generator_test_helpers.dart";

void main() {
  group("SessionMetadataGenerator.generate — failure modes", () {
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
        sendMessageResponse: assistantMessage(
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
  });
}
