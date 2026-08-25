import "package:opencode_plugin/src/models/openapi/assistant_message.g.dart";
import "package:opencode_plugin/src/models/openapi/user_message.g.dart";
import "package:opencode_plugin/src/models/sse_event_data.g.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

import "support/open_code_fixtures.dart";

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

UserMessage _userMessage({required String id}) {
  return UserMessage(
    id: id,
    sessionID: "session-1",
    time: const UserMessageTime(created: 100),
    format: null,
    summary: null,
    agent: "build",
    model: const UserMessageModel(providerID: "openai", modelID: "gpt-4", variant: null),
    system: null,
    tools: null,
  );
}

void main() {
  group("SseEventMapper", () {
    final mapper = SseEventMapper();

    test("maps a live errored assistant message.updated to the error role", () {
      final result = mapper.map(
        SseEventData.messageUpdated(
          info: _assistantMessage(
            error: <String, dynamic>{
              "name": "ProviderAuthError",
              "data": <String, dynamic>{"message": "invalid api key"},
            },
          ),
        ),
      );

      expect(result, isA<BridgeSseMessageUpdated>());
      final event = result! as BridgeSseMessageUpdated;
      // The phone parses this via the shared `Message.fromJson` `role`
      // discriminator, so a live error must arrive as `role: "error"` with
      // flat error fields — not as `role: "assistant"` with the error dropped.
      expect(event.info["role"], equals("error"));
      expect(event.info["errorName"], equals("ProviderAuthError"));
      expect(event.info["errorMessage"], equals("invalid api key"));
    });

    test("maps a live non-errored assistant message.updated to the assistant role", () {
      final result = mapper.map(SseEventData.messageUpdated(info: _assistantMessage(error: null)));

      expect(result, isA<BridgeSseMessageUpdated>());
      final event = result! as BridgeSseMessageUpdated;
      expect(event.info["role"], equals("assistant"));
      expect(event.info.containsKey("errorName"), isFalse);
    });

    test("maps session.created using provided canonical projectID", () {
      final session = openCodeSession(
        id: "session-1",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(SseEventData.sessionCreated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionCreated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
      expect(shared.Session.fromJson(event.info).pluginId, shared.legacyMissingPluginId);
    });

    test("maps session.updated using provided canonical projectID", () {
      final session = openCodeSession(
        id: "session-2",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(SseEventData.sessionUpdated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionUpdated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("maps session.deleted using provided canonical projectID", () {
      final session = openCodeSession(
        id: "session-3",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(SseEventData.sessionDeleted(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionDeleted;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("stamps the resolved prompt id on a user message", () {
      final result = mapper.map(
        SseEventData.messageUpdated(info: _userMessage(id: "msg-sent")),
        promptId: "prm_1",
      );

      expect((result! as BridgeSseMessageUpdated).info["promptId"], equals("prm_1"));
    });

    test("leaves a user message with no resolved prompt unattributed", () {
      final result = mapper.map(SseEventData.messageUpdated(info: _userMessage(id: "msg-from-tui")));

      expect((result! as BridgeSseMessageUpdated).info.containsKey("promptId"), isFalse);
    });
  });
}
