import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("DeepSeek sub-agent lifecycle", () {
    late AcpChildSessionTracker tracker;
    late DeepSeekEventMapper mapper;

    setUp(() {
      tracker = AcpChildSessionTracker();
      mapper = DeepSeekEventMapper(
        launchDirectory: "/launch",
        pluginId: DeepSeekIdentity.id,
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: tracker,
        api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
        messageTimeParser: const DeepSeekMessageTimeParser(),
        subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      )..setSessionProject("root", "/project");
      mapper.setExtensionProtocolVersion(extensionProtocolVersion: DeepSeekAcpApi.extensionProtocolVersion);
      mapper.beginTurn(sessionId: "root", messageId: null);
    });

    tearDown(() => tracker.dispose());

    test("protocol v1 retains generic delegation cards without lifecycle replacements", () {
      mapper.setExtensionProtocolVersion(extensionProtocolVersion: 1);

      final events = mapper.map(_toolCall(toolCallId: "legacy-call", title: "subagent"));

      expect(events.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartTool>());
    });

    test("suppresses exact delegation tool calls and their later updates", () {
      for (final title in const ["subagent", "subagent_fork"]) {
        final toolCallId = "call-$title";
        expect(mapper.map(_toolCall(toolCallId: toolCallId, title: title)), isEmpty);
        expect(mapper.sessionIdForToolCallId(toolCallId: toolCallId), "root");
        expect(mapper.map(_toolUpdate(toolCallId: toolCallId)), isEmpty);
      }

      final ordinary = mapper.map(_toolCall(toolCallId: "ordinary", title: "subagent_read"));
      expect(ordinary.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartTool>());
    });

    test("started announces child, opens a running tile, and retains background mode", () {
      final events = mapper.map(_started(mode: "background"));

      expect(events, hasLength(4));
      final envelope = (events[0] as BridgeSseMessageUpdated).info;
      expect(envelope["id"], "root-subagent-child");
      expect(envelope["sessionID"], "root");
      final child = (events[1] as BridgeSseSessionCreated).info;
      expect(child["id"], "child");
      expect(child["parentID"], "root");
      expect(child["projectID"], "/project");
      expect(child["title"], "Research child");
      expect((events[2] as BridgeSseSessionStatus).status["type"], "busy");
      final tile = (events[3] as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(tile.id, "root-subagent-child-subtask");
      expect(tile.messageID, envelope["id"]);
      expect(tile.prompt, "Inspect the synthetic module");
      expect(tile.description, "Research child");
      expect(tile.agent, DeepSeekIdentity.id);
      expect(tile.childSessionID, "child");
      expect(tile.taskState?.status, PluginToolStatus.running);
      expect(tracker.runningChildren(sessionId: "root").single.isBackground, isTrue);
    });

    test("child standard updates stay attributed to the child transcript", () {
      mapper.map(_started(mode: "foreground"));
      final events = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "messageId": "reply",
              "content": {"type": "text", "text": "Child reply"},
            },
          },
        ),
      );

      final message = events.whereType<BridgeSseMessageUpdated>().single.info;
      expect(message["sessionID"], "child");
      final text = events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartText;
      expect(text.sessionID, "child");
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "Child reply");
    });

    test("child session metadata updates retain root project and parent attribution", () {
      mapper.map(_started(mode: "foreground"));

      final events = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "session_info_update",
              "title": "Updated child",
            },
          },
        ),
      );

      final child = events.whereType<BridgeSseSessionUpdated>().single.info;
      expect(child["projectID"], "/project");
      expect(child["directory"], "/project");
      expect(child["parentID"], "root");
    });

    test("astral terminal summaries remain valid and release root work", () {
      final summary = List.filled(300, "😀").join();
      mapper.map(_started(mode: "foreground"));

      final events = mapper.map(_ended(reason: "completed", summary: summary));

      final tile = (events.first as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(tile.taskState?.output, summary);
      expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    for (final testCase in const [
      (reason: "completed", status: PluginToolStatus.completed, summary: "Done", error: null),
      (reason: "aborted", status: PluginToolStatus.cancelled, summary: null, error: null),
      (reason: "error", status: PluginToolStatus.error, summary: "Failed safely", error: "Failed safely"),
      (
        reason: "max-tokens",
        status: PluginToolStatus.error,
        summary: null,
        error: "DeepSeek sub-agent reached its token limit",
      ),
      (reason: "refusal", status: PluginToolStatus.error, summary: null, error: "DeepSeek sub-agent declined the task"),
    ]) {
      test("ended ${testCase.reason} maps the tile terminal state", () {
        mapper.map(_started(mode: "foreground"));
        final events = mapper.map(_ended(reason: testCase.reason, summary: testCase.summary));

        expect(events, hasLength(2));
        final tile = (events[0] as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
        expect(tile.taskState?.status, testCase.status);
        expect(tile.taskState?.output, testCase.status == PluginToolStatus.completed ? testCase.summary : null);
        expect(tile.taskState?.error, testCase.error);
        expect((events[1] as BridgeSseSessionStatus).status["type"], "idle");
        expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
        expect(tracker.hasRootHold(sessionId: "root"), isFalse);
      });
    }
  });
}

AcpNotification _toolCall({required String toolCallId, required String title}) => AcpNotification(
  method: AcpMethods.sessionUpdate,
  params: {
    "sessionId": "root",
    "update": {
      "sessionUpdate": "tool_call",
      "toolCallId": toolCallId,
      "title": title,
      "status": "in_progress",
    },
  },
);

AcpNotification _toolUpdate({required String toolCallId}) => AcpNotification(
  method: AcpMethods.sessionUpdate,
  params: {
    "sessionId": "root",
    "update": {"sessionUpdate": "tool_call_update", "toolCallId": toolCallId, "status": "completed"},
  },
);

AcpNotification _started({required String mode}) => AcpNotification(
  method: DeepSeekAcpApi.subagentMethod,
  params: {
    "kind": "started",
    "sessionId": "root",
    "childSessionId": "child",
    "toolCallId": "call",
    "prompt": "Inspect the synthetic module",
    "label": "Research child",
    "mode": mode,
  },
);

AcpNotification _ended({required String reason, required String? summary}) => AcpNotification(
  method: DeepSeekAcpApi.subagentMethod,
  params: {
    "kind": "ended",
    "sessionId": "root",
    "childSessionId": "child",
    "stopReason": reason,
    "summary": ?summary,
  },
);
