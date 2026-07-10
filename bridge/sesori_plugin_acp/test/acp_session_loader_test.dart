import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Exercises [AcpReplayCollector] — the `session/load` history reconstruction
/// that the bridge serves to the mobile chat screen.
void main() {
  group("AcpReplayCollector", () {
    Map<String, dynamic> upd(Map<String, dynamic> body) => {"update": body};

    test("reconstructs a user/tool/assistant exchange in order", () {
      final collector = AcpReplayCollector(
        sessionId: "s1",
        agentId: "Cursor",
        modelId: "gpt-5.5",
        providerId: "cursor",
      )
        ..consume(upd({
          "sessionUpdate": "user_message_chunk",
          "content": {"type": "text", "text": "list md files"},
        }))
        ..consume(upd({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "execute",
          "title": "find . -name '*.md'",
          "status": "pending",
        }))
        ..consume(upd({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
          "rawOutput": {"exitCode": 0, "stdout": "README.md\n", "stderr": ""},
        }))
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "There is 1 file."},
        }));

      final messages = collector.build();
      expect(messages, hasLength(2));

      final user = messages.first;
      expect(user.info, isA<PluginMessageUser>());
      expect(user.parts.single.text, "list md files");

      final assistant = messages.last;
      expect(assistant.info, isA<PluginMessageAssistant>());
      final toolPart = assistant.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.state?.status, PluginToolStatus.completed);
      expect(toolPart.state?.output, "README.md");
      final textPart = assistant.parts.firstWhere((p) => p.type == PluginMessagePartType.text);
      expect(textPart.text, "There is 1 file.");
    });

    test("a partial (output-only) update does not reset a completed tool to pending", () {
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "execute",
          "status": "pending",
        }))
        ..consume(upd({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "status": "completed",
          "rawOutput": {"stdout": "done"},
        }))
        // An output-only update with NO status must keep the completed state.
        ..consume(upd({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "rawOutput": {"stdout": "done (final)"},
        }));

      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.state?.status, PluginToolStatus.completed, reason: "status-less update must not reset to pending");
      expect(toolPart.state?.output, "done (final)");
    });

    test("a title-only tool_call_update merges onto an existing draft (matches live)", () {
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "edit",
          "status": "pending",
        }))
        // A separate title-only update after the tool_call: replay must apply it
        // (the live mapper does), not silently drop it.
        ..consume(upd({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "t1",
          "title": "Edit main.dart",
          "status": "in_progress",
        }));
      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.tool, "edit");
      expect(toolPart.state?.title, "Edit main.dart");
    });

    test("a non-string tool title does not throw mid-replay", () {
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "read",
          "title": {"unexpected": "object"},
          "status": "completed",
          "rawOutput": {"stdout": "x"},
        }));
      final toolPart = collector.build().single.parts.firstWhere((p) => p.type == PluginMessagePartType.tool);
      expect(toolPart.tool, "read");
      expect(toolPart.state?.title, isNull);
    });

    test("stamps replayed assistant messages with the loaded session model", () {
      final collector = AcpReplayCollector(
        sessionId: "s1",
        agentId: "Cursor",
        modelId: "claude-opus-4-8",
        providerId: "cursor",
      )..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "hi"},
        }));
      final assistant = collector.build().single.info as PluginMessageAssistant;
      expect(assistant.modelID, "claude-opus-4-8");
      expect(assistant.providerID, "cursor");
    });

    test("a messageId change splits consecutive same-role chunks into two messages", () {
      // ACP v1: chunks of one message share a messageId; a change starts a new
      // message. Without honouring it, distinct same-role messages collapse.
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": "first"},
        }))
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": " message"},
        }))
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m2",
          "content": {"type": "text", "text": "second message"},
        }));

      final messages = collector.build();
      expect(messages, hasLength(2));
      expect(messages[0].parts.single.text, "first message");
      expect(messages[1].parts.single.text, "second message");
      expect(messages[0].info.id, isNot(messages[1].info.id));
    });

    test("chunks without a messageId keep the role-grouping behaviour", () {
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "one"},
        }))
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": " flow"},
        }));
      expect(collector.build().single.parts.single.text, "one flow");
    });

    test("a same-message thought and text share the message; tools attach without an id", () {
      final collector = AcpReplayCollector(sessionId: "s1", agentId: "Cursor")
        ..consume(upd({
          "sessionUpdate": "agent_thought_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": "thinking"},
        }))
        ..consume(upd({
          "sessionUpdate": "tool_call",
          "toolCallId": "t1",
          "kind": "read",
          "status": "completed",
        }))
        ..consume(upd({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": "answer"},
        }));

      final message = collector.build().single;
      expect(message.parts.map((p) => p.type), containsAll(<PluginMessagePartType>[
        PluginMessagePartType.reasoning,
        PluginMessagePartType.text,
        PluginMessagePartType.tool,
      ]));
    });
  });
}
