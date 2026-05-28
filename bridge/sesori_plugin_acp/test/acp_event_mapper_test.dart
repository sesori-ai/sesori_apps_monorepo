import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

/// Asserts the mapper emits sesori-schema payloads — message envelopes must
/// round-trip through `Message.fromJson`, exactly like the codex mapper.
void main() {
  group("AcpEventMapper", () {
    late AcpEventMapper mapper;

    setUp(() {
      mapper = AcpEventMapper(projectCwd: "/repo", agentId: "cursor")
        ..currentModelId = "gpt-5.4"
        ..currentProviderId = "cursor";
    });

    AcpNotification update(Map<String, dynamic> body) => AcpNotification(
      method: "session/update",
      params: {"sessionId": "s1", "update": body},
    );

    test("agent_message_chunk emits envelope + part + delta on first chunk", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Hello"},
        }),
      );

      final updated = events.whereType<BridgeSseMessageUpdated>().single;
      final message = shared.Message.fromJson(updated.info);
      expect(message, isA<shared.MessageAssistant>());

      expect(events.whereType<BridgeSseMessagePartUpdated>(), hasLength(1));
      final delta = events.whereType<BridgeSseMessagePartDelta>().single;
      expect(delta.delta, "Hello");
      expect(delta.field, "text");
    });

    test("subsequent chunks emit only a delta on the same part", () {
      mapper.beginTurn("s1");
      mapper.map(update({
        "sessionUpdate": "agent_message_chunk",
        "content": {"type": "text", "text": "Hel"},
      }));
      final second = mapper.map(update({
        "sessionUpdate": "agent_message_chunk",
        "content": {"type": "text", "text": "lo"},
      }));
      expect(second.whereType<BridgeSseMessageUpdated>(), isEmpty);
      expect(second.whereType<BridgeSseMessagePartDelta>().single.delta, "lo");
    });

    test("agent_thought_chunk maps to a reasoning part", () {
      mapper.beginTurn("s1");
      final events = mapper.map(update({
        "sessionUpdate": "agent_thought_chunk",
        "content": {"type": "text", "text": "thinking"},
      }));
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.type, PluginMessagePartType.reasoning);
    });

    test("tool_call maps to an assistant message with a tool part", () {
      final events = mapper.map(update({
        "sessionUpdate": "tool_call",
        "toolCallId": "tc-1",
        "title": "Read file",
        "kind": "read",
        "status": "pending",
      }));
      final updated = events.whereType<BridgeSseMessageUpdated>().single;
      expect(shared.Message.fromJson(updated.info), isA<shared.MessageAssistant>());
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.type, PluginMessagePartType.tool);
      expect(part.tool, "read");
      expect(part.state?.status, "pending");
    });

    test("tool_call_update on an edit emits a session diff", () {
      final events = mapper.map(update({
        "sessionUpdate": "tool_call_update",
        "toolCallId": "tc-2",
        "kind": "edit",
        "status": "completed",
      }));
      expect(events.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("plan maps to a todo update, commands to a project update", () {
      expect(
        mapper.map(update({"sessionUpdate": "plan", "entries": const <Object?>[]})).single,
        isA<BridgeSseTodoUpdated>(),
      );
      expect(
        mapper.map(update({"sessionUpdate": "available_commands_update"})).single,
        isA<BridgeSseProjectUpdated>(),
      );
    });

    test("unknown variants are dropped", () {
      expect(mapper.map(update({"sessionUpdate": "current_mode_update"})), isEmpty);
    });
  });
}
