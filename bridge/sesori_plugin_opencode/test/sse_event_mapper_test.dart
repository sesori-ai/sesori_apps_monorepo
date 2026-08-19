import "package:opencode_plugin/src/models/openapi/assistant_message.g.dart";
import "package:opencode_plugin/src/models/openapi/reasoning_part.g.dart";
import "package:opencode_plugin/src/models/openapi/session.g.dart";
import "package:opencode_plugin/src/models/openapi/session_status.g.dart";
import "package:opencode_plugin/src/models/openapi/text_part.g.dart";
import "package:opencode_plugin/src/models/sse_event_data.g.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
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
  group("SseEventMapper", () {
    late SseEventMapper mapper;

    setUp(() {
      mapper = SseEventMapper();
    });

    test("maps a live errored assistant message.updated to the error role", () {
      final result = mapper
          .map(
            SseEventData.messageUpdated(
              info: _assistantMessage(
                error: <String, dynamic>{
                  "name": "ProviderAuthError",
                  "data": <String, dynamic>{"message": "invalid api key"},
                },
              ),
            ),
          )
          .single;

      expect(result, isA<BridgeSseMessageUpdated>());
      final event = result as BridgeSseMessageUpdated;
      // The phone parses this via the shared `Message.fromJson` `role`
      // discriminator, so a live error must arrive as `role: "error"` with
      // flat error fields — not as `role: "assistant"` with the error dropped.
      expect(event.info["role"], equals("error"));
      expect(event.info["errorName"], equals("ProviderAuthError"));
      expect(event.info["errorMessage"], equals("invalid api key"));
    });

    test("maps a live non-errored assistant message.updated to the assistant role", () {
      final result = mapper.map(SseEventData.messageUpdated(info: _assistantMessage(error: null))).single;

      expect(result, isA<BridgeSseMessageUpdated>());
      final event = result as BridgeSseMessageUpdated;
      expect(event.info["role"], equals("assistant"));
      expect(event.info.containsKey("errorName"), isFalse);
    });

    test("maps session.created using provided canonical projectID", () {
      const session = Session(
        slug: "slug",
        title: "title",
        version: "v",
        time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
        id: "session-1",
        projectID: "/repo",
        directory: "/repo/packages/foo",
        workspaceID: null,
        path: null,
        parentID: null,
        summary: null,
        cost: null,
        tokens: null,
        share: null,
        agent: null,
        model: null,
        metadata: null,
        permission: null,
        revert: null,
      );

      final result = mapper.map(const SseEventData.sessionCreated(info: session)).single;

      final event = result as BridgeSseSessionCreated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
      expect(shared.Session.fromJson(event.info).pluginId, shared.legacyMissingPluginId);
    });

    test("maps session.updated using provided canonical projectID", () {
      const session = Session(
        slug: "slug",
        title: "title",
        version: "v",
        time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
        id: "session-2",
        projectID: "/repo",
        directory: "/repo/packages/foo",
        workspaceID: null,
        path: null,
        parentID: null,
        summary: null,
        cost: null,
        tokens: null,
        share: null,
        agent: null,
        model: null,
        metadata: null,
        permission: null,
        revert: null,
      );

      final result = mapper.map(const SseEventData.sessionUpdated(info: session)).single;

      final event = result as BridgeSseSessionUpdated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("maps session.deleted using provided canonical projectID", () {
      const session = Session(
        slug: "slug",
        title: "title",
        version: "v",
        time: SessionTime(created: 0, updated: 0, compacting: null, archived: null),
        id: "session-3",
        projectID: "/repo",
        directory: "/repo/packages/foo",
        workspaceID: null,
        path: null,
        parentID: null,
        summary: null,
        cost: null,
        tokens: null,
        share: null,
        agent: null,
        model: null,
        metadata: null,
        permission: null,
        revert: null,
      );

      final result = mapper.map(const SseEventData.sessionDeleted(info: session)).single;

      final event = result as BridgeSseSessionDeleted;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("finalizes active reasoning before following assistant output", () {
      mapper.map(
        const SseEventData.messagePartUpdated(
          part: ReasoningPart(
            id: "reasoning-1",
            sessionID: "session-1",
            messageID: "message-1",
            text: "",
            metadata: null,
            time: ReasoningPartTime(start: 1, end: null),
          ),
        ),
      );
      mapper.map(
        const SseEventData.messagePartDelta(
          sessionID: "session-1",
          messageID: "message-1",
          partID: "reasoning-1",
          field: "text",
          delta: "Inspecting workflows",
        ),
      );

      final events = mapper.map(
        const SseEventData.messagePartUpdated(
          part: TextPart(
            id: "text-1",
            sessionID: "session-1",
            messageID: "message-1",
            text: "",
            synthetic: null,
            ignored: null,
            time: TextPartTime(start: 2, end: null),
            metadata: null,
          ),
        ),
      );

      expect(events, hasLength(2));
      final reasoning = (events.first as BridgeSseMessagePartUpdated).part;
      expect(reasoning.type, PluginMessagePartType.reasoning);
      expect(reasoning.text, "Inspecting workflows");
      expect((events.last as BridgeSseMessagePartUpdated).part.type, PluginMessagePartType.text);

      mapper.map(
        const SseEventData.messagePartDelta(
          sessionID: "session-1",
          messageID: "message-1",
          partID: "reasoning-1",
          field: "text",
          delta: "late",
        ),
      );
      final laterOutput = mapper.map(
        const SseEventData.messagePartUpdated(
          part: TextPart(
            id: "text-2",
            sessionID: "session-1",
            messageID: "message-1",
            text: "answer",
            synthetic: null,
            ignored: null,
            time: TextPartTime(start: 3, end: 4),
            metadata: null,
          ),
        ),
      );
      expect(laterOutput, hasLength(1));
      expect((laterOutput.single as BridgeSseMessagePartUpdated).part.type, PluginMessagePartType.text);
    });

    test("idle finalizes reasoning when OpenCode omits its final snapshot", () {
      mapper.map(
        const SseEventData.messagePartUpdated(
          part: ReasoningPart(
            id: "reasoning-idle",
            sessionID: "session-idle",
            messageID: "message-idle",
            text: "",
            metadata: null,
            time: ReasoningPartTime(start: 1, end: null),
          ),
        ),
      );
      mapper.map(
        const SseEventData.messagePartDelta(
          sessionID: "session-idle",
          messageID: "message-idle",
          partID: "reasoning-idle",
          field: "text",
          delta: "Complete thought",
        ),
      );

      final events = mapper.map(
        const SseEventData.sessionStatus(
          sessionID: "session-idle",
          status: SessionStatusIdle(),
        ),
      );

      expect(events, hasLength(2));
      expect((events.first as BridgeSseMessagePartUpdated).part.text, "Complete thought");
      expect(events.last, isA<BridgeSseSessionStatus>());
    });

    for (final boundary in <(String, SseEventData)>[
      ("reconnect", const SseEventData.serverConnected()),
      ("instance disposal", const SseEventData.serverInstanceDisposed(directory: "/repo")),
    ]) {
      test("${boundary.$1} drops incomplete reasoning state", () {
        mapper.map(
          const SseEventData.messagePartUpdated(
            part: ReasoningPart(
              id: "reasoning-stale",
              sessionID: "session-stale",
              messageID: "message-stale",
              text: "",
              metadata: null,
              time: ReasoningPartTime(start: 1, end: null),
            ),
          ),
        );
        mapper.map(
          const SseEventData.messagePartDelta(
            sessionID: "session-stale",
            messageID: "message-stale",
            partID: "reasoning-stale",
            field: "text",
            delta: "Incomplete before the gap",
          ),
        );

        mapper.map(boundary.$2);
        final events = mapper.map(
          const SseEventData.messagePartUpdated(
            part: TextPart(
              id: "text-after-gap",
              sessionID: "session-stale",
              messageID: "message-stale",
              text: "",
              synthetic: null,
              ignored: null,
              time: TextPartTime(start: 2, end: null),
              metadata: null,
            ),
          ),
        );

        expect(events, hasLength(1));
        expect((events.single as BridgeSseMessagePartUpdated).part.type, PluginMessagePartType.text);
      });
    }
  });
}
