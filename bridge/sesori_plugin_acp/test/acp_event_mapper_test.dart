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
      mapper = AcpEventMapper(launchDirectory: "/repo", agentId: "cursor")
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
      expect(part.state?.status, PluginToolStatus.pending);
    });

    test("tool_call falls through an empty kind to title and never throws", () {
      // Same fail-soft name resolution as tool_call_update: an empty-string
      // `kind` must fall through to `title`, and a non-string `kind` must not
      // throw during live mapping.
      final emptyKind = mapper.map(update({
        "sessionUpdate": "tool_call",
        "toolCallId": "tc-empty",
        "kind": "",
        "title": "Search files",
        "status": "pending",
      }));
      expect(
        emptyKind.whereType<BridgeSseMessagePartUpdated>().single.part.tool,
        "Search files",
      );

      final nonStringKind = mapper.map(update({
        "sessionUpdate": "tool_call",
        "toolCallId": "tc-bad",
        "kind": 123,
        "status": "pending",
      }));
      expect(
        nonStringKind.whereType<BridgeSseMessagePartUpdated>().single.part.tool,
        "tool",
      );
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

    test("tool_call_update surfaces rawOutput stdout/stderr as the part output", () {
      final events = mapper.map(update({
        "sessionUpdate": "tool_call_update",
        "toolCallId": "tc-3",
        "kind": "execute",
        "title": "ls",
        "status": "completed",
        "rawOutput": {"exitCode": 0, "stdout": "a.dart\nb.dart\n", "stderr": ""},
      }));
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.status, PluginToolStatus.completed);
      expect(part.state?.output, "a.dart\nb.dart");
      expect(part.state?.error, isNull);
    });

    test("read-style tool surfaces rawOutput.content", () {
      final events = mapper.map(update({
        "sessionUpdate": "tool_call_update",
        "toolCallId": "tc-read",
        "kind": "read",
        "title": "Read notes.txt",
        "status": "completed",
        "rawOutput": {"content": "hello from cursor e2e\n"},
      }));
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.output, "hello from cursor e2e");
    });

    test("failed tool_call_update mirrors output into error", () {
      final events = mapper.map(update({
        "sessionUpdate": "tool_call_update",
        "toolCallId": "tc-4",
        "kind": "execute",
        "status": "failed",
        "rawOutput": {"exitCode": 1, "stdout": "", "stderr": "boom"},
      }));
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.output, "boom");
      expect(part.state?.error, "boom");
    });

    test("oversized tool output is truncated", () {
      final big = "x" * (maxToolOutputLength + 50);
      final events = mapper.map(update({
        "sessionUpdate": "tool_call_update",
        "toolCallId": "tc-5",
        "kind": "execute",
        "status": "completed",
        "rawOutput": {"stdout": big, "stderr": ""},
      }));
      final output = events.whereType<BridgeSseMessagePartUpdated>().single.part.state?.output;
      expect(output, hasLength(maxToolOutputLength + 1)); // 500 chars + ellipsis
      expect(output, endsWith("…"));
    });

    test("session_info_update surfaces the title as a session update", () {
      final events = mapper.map(update({
        "sessionUpdate": "session_info_update",
        "title": "Fix the parser",
      }));
      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      final session = shared.Session.fromJson(updated.info);
      expect(session.id, "s1");
      expect(session.title, "Fix the parser");
      // No per-session project recorded -> falls back to the launch cwd.
      expect(session.projectID, "/repo");
      expect(session.directory, "/repo");
    });

    test("session_info_update files the title under the session's own project", () {
      // A session opened outside the launch cwd: its title update must carry
      // that project's id, or the mobile session list (which drops updates whose
      // projectID != the active project) ignores it.
      mapper.setSessionProject("s1", "/repo/opened-elsewhere");
      final events = mapper.map(update({
        "sessionUpdate": "session_info_update",
        "title": "Title in opened project",
      }));
      final session =
          shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.projectID, "/repo/opened-elsewhere");
      expect(session.directory, "/repo/opened-elsewhere");
    });

    test("clearing a session's project reverts to the launch cwd", () {
      mapper.setSessionProject("s1", "/repo/opened-elsewhere");
      mapper.setSessionProject("s1", null);
      final events = mapper.map(update({
        "sessionUpdate": "session_info_update",
        "title": "Back to default",
      }));
      final session =
          shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.projectID, "/repo");
    });

    test("a per-session model overrides the global stamp", () {
      mapper
        ..currentModelId = "composer-2.5"
        ..setSessionModel("s1", "claude-opus-4-8", providerId: "cursor");
      mapper.beginTurn("s1");
      final events = mapper.map(update({
        "sessionUpdate": "agent_message_chunk",
        "content": {"type": "text", "text": "hi"},
      }));
      final message =
          shared.Message.fromJson(events.whereType<BridgeSseMessageUpdated>().single.info)
              as shared.MessageAssistant;
      expect(message.modelID, "claude-opus-4-8");
      expect(message.providerID, "cursor");
    });

    test("unknown variants are dropped", () {
      expect(mapper.map(update({"sessionUpdate": "current_mode_update"})), isEmpty);
    });
  });
}
