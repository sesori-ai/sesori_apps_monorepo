import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/grok_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

const String _root = "01a00000-0000-7000-8000-000000000001";
const String _child = "01a00000-0000-7000-8000-000000000002";
const String _toolCallId = "call-00000000-0000-4000-8000-000000000000-0";
const String _tileMessageId = "$_root-subagent-$_child";

AcpNotification _fixture(String name) {
  final decoded = jsonDecode(File("test/fixtures/protocol/v1/$name").readAsStringSync()) as Map;
  final frame = decoded.cast<String, dynamic>();
  return AcpNotification(
    method: frame["method"] as String,
    params: (frame["params"] as Map).cast<String, dynamic>(),
  );
}

PluginMessagePartSubtask _subtask(BridgeSseEvent event) =>
    (event as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;

void main() {
  group("GrokEventMapper sub-agent lifecycle", () {
    late AcpChildSessionTracker tracker;
    late AcpSessionConfigurationTracker configuration;
    late GrokEventMapper mapper;

    setUp(() {
      tracker = AcpChildSessionTracker();
      configuration = AcpSessionConfigurationTracker()
        ..setProcessDefaults(modelId: "synthetic:default", providerId: "xai")
        ..setSessionOverride(sessionId: _root, modelId: "synthetic:root", providerId: "xai");
      mapper = GrokEventMapper(
        launchDirectory: "/launch",
        pluginId: "grok",
        configurationTracker: configuration,
        childSessions: tracker,
      )..setSessionProject(_root, "/project");
      mapper.beginTurn(sessionId: _root, messageId: null);
    });

    test("the spawn_subagent tool call renders no card and its updates are dropped", () {
      expect(mapper.map(_fixture("subagent_tool_call.json")), isEmpty);
      expect(mapper.sessionIdForToolCallId(toolCallId: _toolCallId), _root, reason: "permission attribution");
      final completed = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": _root,
            "update": {"sessionUpdate": "tool_call_update", "toolCallId": _toolCallId, "status": "completed"},
          },
        ),
      );
      expect(completed, isEmpty);
      expect(tracker.childStatuses, isEmpty);
    });

    test("subagent_spawned creates the child under the root's project; the child's prompt opens the tile", () {
      mapper.map(_fixture("subagent_tool_call.json"));
      final spawned = mapper.map(_fixture("subagent_spawned.json"));
      expect(spawned, hasLength(2));
      final created = shared.Session.fromJson((spawned[0] as BridgeSseSessionCreated).info);
      expect(created.id, _child);
      expect(created.parentID, _root);
      expect(created.directory, "/project");
      expect(created.projectID, "/project");
      expect(created.title, "Synthetic child task");
      expect(shared.SessionStatus.fromJson((spawned[1] as BridgeSseSessionStatus).status), const shared.SessionStatus.busy());
      expect(tracker.busyChildIds(sessionId: _root), {_child});
      expect(tracker.runningChildren(sessionId: _root).single.isBackground, isFalse);

      final prompted = mapper.map(_fixture("subagent_child_prompt.json"));
      final envelope = shared.Message.fromJson(prompted.whereType<BridgeSseMessageUpdated>().single.info);
      expect(envelope, isA<shared.MessageAssistant>());
      expect(envelope.id, _tileMessageId);
      expect(envelope.sessionID, _root);
      final tile = _subtask(prompted.whereType<BridgeSseMessagePartUpdated>().single);
      expect(tile.sessionID, _root);
      expect(tile.messageID, _tileMessageId);
      expect(tile.prompt, "Synthetic child prompt");
      expect(tile.description, "Synthetic child task");
      expect(tile.agent, "general-purpose");
      expect(tile.childSessionID, _child);
      expect(tile.taskState?.status, PluginToolStatus.running);
    });

    test("the child's reported model stamps its own messages", () {
      mapper.map(_fixture("subagent_spawned.json"));
      expect(mapper.modelForSession(sessionId: _child), "synthetic:model-alpha");
      expect(mapper.providerForSession(sessionId: _child), "xai");
      expect(mapper.modelForSession(sessionId: _root), "synthetic:root");
    });

    test("a reordered spawn tool_call_update opens no tool card either", () {
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": _root,
            "update": {
              "sessionUpdate": "tool_call_update",
              "toolCallId": _toolCallId,
              "status": "completed",
              "_meta": {
                "x.ai/tool": {"name": "spawn_subagent", "kind": "task"},
              },
            },
          },
        ),
      );
      expect(events, isEmpty);
      expect(mapper.map(_fixture("subagent_tool_call.json")), isEmpty);
    });

    test("an unclassifiable partial update before the spawn call is retired by the call", () {
      const partial = AcpNotification(
        method: "session/update",
        params: {
          "sessionId": _root,
          "update": {"sessionUpdate": "tool_call_update", "toolCallId": _toolCallId, "status": "in_progress"},
        },
      );
      expect(mapper.map(partial).whereType<BridgeSseMessagePartUpdated>(), hasLength(1), reason: "no _meta yet");
      expect(mapper.map(_fixture("subagent_tool_call.json")), isEmpty);
      expect(mapper.map(partial), isEmpty, reason: "suppressed once the call identified the spawn");
    });

    test("a spawn with an empty child id is undeliverable and dropped", () {
      expect(
        mapper.map(
          const AcpNotification(
            method: GrokEventMapper.sessionNotificationMethod,
            params: {
              "sessionId": _root,
              "update": {"sessionUpdate": "subagent_spawned", "subagent_id": "", "child_session_id": ""},
            },
          ),
        ),
        isEmpty,
      );
      expect(tracker.childStatuses, isEmpty);
      expect(mapper.modelForSession(sessionId: ""), "synthetic:default");
    });

    test("a root user chunk is still dropped", () {
      expect(
        mapper.map(
          const AcpNotification(
            method: "session/update",
            params: {
              "sessionId": _root,
              "update": {
                "sessionUpdate": "user_message_chunk",
                "content": {"type": "text", "text": "echo"},
              },
            },
          ),
        ),
        isEmpty,
      );
    });

    test("subagent_progress redraws nothing", () {
      mapper
        ..map(_fixture("subagent_spawned.json"))
        ..map(_fixture("subagent_child_prompt.json"));
      expect(mapper.map(_fixture("subagent_progress.json")), isEmpty);
    });

    test("subagent_finished completed closes the tile with its output and idles the child", () {
      mapper
        ..map(_fixture("subagent_spawned.json"))
        ..map(_fixture("subagent_child_prompt.json"));

      final events = mapper.map(_fixture("subagent_finished_completed.json"));
      expect(events, hasLength(2));
      final tile = _subtask(events[0]);
      expect(tile.messageID, _tileMessageId);
      expect(tile.taskState?.status, PluginToolStatus.completed);
      expect(tile.taskState?.output, "synthetic final text");
      expect(shared.SessionStatus.fromJson((events[1] as BridgeSseSessionStatus).status), const shared.SessionStatus.idle());
      expect(tracker.childStatuses, {_child: const PluginSessionStatus.idle()});
    });

    test("subagent_finished cancelled marks the tile cancelled", () {
      mapper
        ..map(_fixture("subagent_spawned.json"))
        ..map(_fixture("subagent_child_prompt.json"));

      final tile = _subtask(mapper.map(_fixture("subagent_finished_cancelled.json"))[0]);
      expect(tile.taskState?.status, PluginToolStatus.cancelled);
      expect(tile.taskState?.error, isNull);
      expect(tile.taskState?.output, isNull);
    });

    test("the tracker survives the turn boundary", () {
      mapper
        ..map(_fixture("subagent_spawned.json"))
        ..map(_fixture("subagent_child_prompt.json"))
        ..beginTurn(sessionId: _root, messageId: "next-turn");

      final events = mapper.map(_fixture("subagent_finished_completed.json"));
      expect(_subtask(events[0]).messageID, _tileMessageId);
    });

    test("an unknown status parses to the unknown lifecycle state", () {
      mapper
        ..map(_fixture("subagent_spawned.json"))
        ..map(_fixture("subagent_child_prompt.json"));
      final tile = _subtask(
        mapper.map(
          const AcpNotification(
            method: GrokEventMapper.sessionNotificationMethod,
            params: {
              "sessionId": _root,
              "update": {
                "sessionUpdate": "subagent_finished",
                "subagent_id": _child,
                "child_session_id": _child,
                "status": "evaporated",
              },
            },
          ),
        )[0],
      );
      expect(tile.taskState?.status, PluginToolStatus.unknown);
    });

    test("other x.ai updates, malformed payloads, and foreign methods are dropped", () {
      expect(
        mapper.map(
          const AcpNotification(
            method: GrokEventMapper.sessionNotificationMethod,
            params: {
              "sessionId": _root,
              "update": {"sessionUpdate": "turn_completed", "stop_reason": "end_turn"},
            },
          ),
        ),
        isEmpty,
      );
      expect(
        mapper.map(
          const AcpNotification(
            method: GrokEventMapper.sessionNotificationMethod,
            params: {
              "sessionId": _root,
              "update": {"sessionUpdate": "subagent_spawned", "subagent_id": 7},
            },
          ),
        ),
        isEmpty,
      );
      expect(
        mapper.map(const AcpNotification(method: "_x.ai/queue/changed", params: {"sessionId": _root})),
        isEmpty,
      );
      expect(tracker.childStatuses, isEmpty);
    });

    test("an ordinary Grok tool call still renders as a tool card", () {
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": _root,
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "call-plain",
              "title": "run_terminal_command",
              "rawInput": {"command": "true"},
              "_meta": {
                "x.ai/tool": {"name": "run_terminal_command", "kind": "execute"},
              },
            },
          },
        ),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part, isA<PluginMessagePartTool>());
    });
  });
}
