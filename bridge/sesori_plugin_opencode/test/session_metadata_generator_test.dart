import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

import "session_metadata_generator_test_helpers.dart";

void main() {
  group("SessionMetadataGenerator.generate", () {
    test("happy path returns SessionMetadata", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "anthropic/claude-haiku-3"),
        sendMessageResponse: assistantMessage(
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

    test("returns null when provider ID is empty (model starts with /)", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "/claude-haiku"),
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

    test("returns null when model ID is empty (model ends with /)", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "anthropic/"),
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
        sendMessageResponse: assistantMessage(
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

    test("extracts embedded JSON from trailing text", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: assistantMessage(
          text: 'Here is your JSON: {"title":"Fix Bug","branchName":"fix-bug"} I hope that helps!',
        ),
      );
      final generator = SessionMetadataGenerator(api: api);

      final metadata = await generator.generate(
        firstMessage: "hello",
        directory: "/repo",
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, equals("Fix Bug"));
      expect(metadata.branchName, equals("fix-bug"));
    });

    test("returns null for invalid JSON", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: assistantMessage(text: "not-json"),
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
        sendMessageResponse: assistantMessage(
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
        sendMessageResponse: assistantMessage(
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

    test("truncates long first message to 500 chars", () async {
      final api = FakeOpenCodeApi(
        config: const OpenCodeConfig(smallModel: "openai/gpt-4o-mini"),
        sendMessageResponse: assistantMessage(
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
