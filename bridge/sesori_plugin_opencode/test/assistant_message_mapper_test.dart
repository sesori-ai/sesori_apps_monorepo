import "package:opencode_plugin/src/assistant_message_mapper.dart";
import "package:opencode_plugin/src/models/openapi/assistant_message.g.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

AssistantMessage _assistantMessage({required Object? error}) {
  return AssistantMessage(
    id: "msg-1",
    sessionID: "session-1",
    time: const AssistantMessageTime(created: 100, completed: 200),
    error: error,
    parentID: "parent-1",
    modelID: "gpt-4",
    providerID: "openai",
    mode: "build",
    agent: "general",
    path: const AssistantMessagePath(cwd: "/repo", root: "/repo"),
    summary: null,
    cost: 0,
    tokens: const AssistantMessageTokens(
      total: 0,
      input: 0,
      output: 0,
      reasoning: 0,
      cache: AssistantMessageTokensCache(read: 0, write: 0),
    ),
    structured: null,
    variant: null,
    finish: null,
  );
}

void main() {
  group("AssistantMessageMapper", () {
    const mapper = AssistantMessageMapper();

    test("maps a non-errored assistant message to PluginMessage.assistant", () {
      final result = mapper.map(_assistantMessage(error: null));

      expect(result, isA<PluginMessageAssistant>());
      final assistant = result as PluginMessageAssistant;
      expect(assistant.id, equals("msg-1"));
      expect(assistant.sessionID, equals("session-1"));
      expect(assistant.agent, equals("general"));
      expect(assistant.modelID, equals("gpt-4"));
      expect(assistant.providerID, equals("openai"));
      expect(assistant.time?.created, equals(100));
      expect(assistant.time?.completed, equals(200));
    });

    test("collapses an errored assistant message to PluginMessage.error with flat fields", () {
      final result = mapper.map(
        _assistantMessage(
          error: <String, dynamic>{
            "name": "ProviderAuthError",
            "data": <String, dynamic>{"message": "invalid api key"},
          },
        ),
      );

      expect(result, isA<PluginMessageError>());
      final error = result as PluginMessageError;
      expect(error.id, equals("msg-1"));
      expect(error.sessionID, equals("session-1"));
      expect(error.errorName, equals("ProviderAuthError"));
      expect(error.errorMessage, equals("invalid api key"));
      expect(error.modelID, equals("gpt-4"));
      expect(error.providerID, equals("openai"));
      expect(error.time?.created, equals(100));
    });

    test("falls back to placeholders when the error shape is missing fields", () {
      final result = mapper.map(_assistantMessage(error: <String, dynamic>{}));

      expect(result, isA<PluginMessageError>());
      final error = result as PluginMessageError;
      expect(error.errorName, equals("UnknownError"));
      expect(error.errorMessage, equals("Unknown error"));
    });

    test("maps a non-map (string) error payload to PluginMessage.error via toString", () {
      // OpenCode types `error` as `Object?`, so a bare string is possible. A
      // present error must never fall through as a plain assistant message.
      final result = mapper.map(_assistantMessage(error: "Internal Server Error"));

      expect(result, isA<PluginMessageError>());
      final error = result as PluginMessageError;
      expect(error.errorName, equals("UnknownError"));
      expect(error.errorMessage, equals("Internal Server Error"));
    });

    test("serializes an errored message to the shared MessageError JSON shape", () {
      final result = mapper.map(
        _assistantMessage(
          error: <String, dynamic>{
            "name": "Boom",
            "data": <String, dynamic>{"message": "kaboom"},
          },
        ),
      );

      // The phone re-parses this map via the shared `Message.fromJson`, which
      // dispatches on `role`. It must read as an error, not an assistant.
      final json = result.toJson();
      expect(json["role"], equals("error"));
      expect(json["errorName"], equals("Boom"));
      expect(json["errorMessage"], equals("kaboom"));
    });
  });
}
