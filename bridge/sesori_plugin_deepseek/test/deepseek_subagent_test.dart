import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("DeepSeek sub-agent lifecycle", () {
    late AcpChildSessionTracker tracker;
    late AcpSessionConfigurationTracker configurationTracker;
    late DeepSeekEventMapper mapper;

    setUp(() {
      tracker = AcpChildSessionTracker();
      configurationTracker = AcpSessionConfigurationTracker();
      mapper = DeepSeekEventMapper(
        launchDirectory: "/launch",
        pluginId: DeepSeekIdentity.id,
        configurationTracker: configurationTracker,
        childSessions: tracker,
        api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
        messageTimeParser: const DeepSeekMessageTimeParser(),
        subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
        delegationTracker: DeepSeekDelegationTracker(),
      )..setSessionProject("root", "/project");
      mapper.beginTurn(sessionId: "root", messageId: null);
    });

    tearDown(() => tracker.dispose());

    test("sub-agent lifecycle frames opt into accepted-prompt write ordering", () {
      expect(mapper.shouldBufferDuringPromptWrite(notification: _started(mode: "foreground")), isTrue);
      expect(
        mapper.shouldBufferDuringPromptWrite(
          notification: _ended(reason: "completed", summary: "Done"),
        ),
        isTrue,
      );
    });

    test("defers exact delegation calls until a correlated start and suppresses later updates", () {
      for (final title in const ["subagent", "subagent_fork"]) {
        final toolCallId = "call-$title";
        final childSessionId = "child-$title";
        expect(mapper.map(_toolCall(toolCallId: toolCallId, title: title)), isEmpty);
        expect(mapper.sessionIdForToolCallId(toolCallId: toolCallId), "root");

        final started = mapper.map(
          _startedWithIdentity(
            parentSessionId: "root",
            mode: "foreground",
            childSessionId: childSessionId,
            toolCallId: toolCallId,
          ),
        );
        expect(started.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartSubtask>());
        expect(mapper.map(_toolUpdate(toolCallId: toolCallId, status: "completed")), isEmpty);
      }

      final ordinary = mapper.map(_toolCall(toolCallId: "ordinary", title: "subagent_read"));
      expect(ordinary.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartTool>());
    });

    test("retains started delegation correlation across parent turns until both sides finish", () {
      expect(mapper.map(_toolCall(toolCallId: "call", title: "subagent")), isEmpty);
      mapper.map(_started(mode: "background"));
      expect(mapper.map(_toolUpdate(toolCallId: "call", status: "completed")), isEmpty);

      mapper.beginTurn(sessionId: "root", messageId: null);
      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "root",
              "update": {"sessionUpdate": "tool_call_update", "toolCallId": "call"},
            },
          ),
        ),
        isEmpty,
      );
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), "root");

      mapper.map(_ended(reason: "completed", summary: "Done"));
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), isNull);
    });

    test("an ambiguous cross-session tool call id does not fall back to the active turn", () {
      mapper.map(_started(mode: "background"));
      mapper.map(
        _startedWithIdentity(
          parentSessionId: "other-root",
          mode: "background",
          childSessionId: "other-child",
          toolCallId: "call",
        ),
      );

      expect(mapper.lookupSessionForToolCallId(toolCallId: "call"), isA<AcpToolCallSessionAmbiguous>());
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), isNull);
    });

    test("a late lifecycle start cannot recreate a deleted child subtree", () {
      mapper.map(_started(mode: "background"));
      mapper.forgetSession("child");
      tracker.forgetSession(sessionId: "child");

      final events = mapper.map(
        _startedWithIdentity(
          parentSessionId: "child",
          mode: "background",
          childSessionId: "late-grandchild",
          toolCallId: "late-call",
        ),
      );

      final repeatedChild = mapper.map(
        _startedWithIdentity(
          parentSessionId: "root",
          mode: "background",
          childSessionId: "child",
          toolCallId: "repeated-child-call",
        ),
      );

      expect(events, isEmpty);
      expect(repeatedChild, isEmpty);
      expect(tracker.isChild(sessionId: "late-grandchild"), isFalse);
      expect(mapper.lookupSessionForToolCallId(toolCallId: "late-call"), isA<AcpToolCallSessionNotFound>());
      expect(
        mapper.lookupSessionForToolCallId(toolCallId: "repeated-child-call"),
        isA<AcpToolCallSessionNotFound>(),
      );
    });

    test("session and live connection resets clear started delegation correlation", () {
      mapper.map(_toolCall(toolCallId: "call", title: "subagent"));
      mapper.map(_started(mode: "background"));
      mapper.forgetSession("root");
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), isNull);

      mapper.map(_toolCall(toolCallId: "call-2", title: "subagent"));
      mapper.map(
        _startedWithIdentity(
          parentSessionId: "root",
          mode: "background",
          childSessionId: "child-2",
          toolCallId: "call-2",
        ),
      );
      mapper.resetLiveState();
      expect(mapper.sessionIdForToolCallId(toolCallId: "call-2"), isNull);
    });

    test("keeps an ended child correlated until the standard terminal update is suppressed", () {
      mapper.map(_toolCall(toolCallId: "call", title: "subagent"));
      mapper.map(_started(mode: "foreground"));

      mapper.map(_ended(reason: "completed", summary: "Done"));
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), "root");
      expect(mapper.map(_toolUpdate(toolCallId: "call", status: "completed")), isEmpty);
      expect(mapper.sessionIdForToolCallId(toolCallId: "call"), isNull);
    });

    test("defers an identifiable delegation update that arrives before its call", () {
      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "root",
              "update": {
                "sessionUpdate": "tool_call_update",
                "toolCallId": "call",
                "title": "subagent",
                "status": "in_progress",
                "rawOutput": "starting",
              },
            },
          ),
        ),
        isEmpty,
      );
      expect(mapper.map(_toolCall(toolCallId: "call", title: "subagent")), isEmpty);

      final events = mapper.map(_started(mode: "foreground"));

      expect(
        events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part),
        everyElement(isA<PluginMessagePartSubtask>()),
      );
      expect(events.whereType<BridgeSseMessagePartUpdated>(), hasLength(1));
    });

    test("retains a generic error card when delegation fails before child start", () {
      expect(mapper.map(_toolCall(toolCallId: "failed-call", title: "subagent")), isEmpty);

      final events = mapper.map(_toolUpdate(toolCallId: "failed-call", status: "failed"));

      final tool = events.whereType<BridgeSseMessagePartUpdated>().last.part as PluginMessagePartTool;
      expect(tool.state.status, PluginToolStatus.error);
      expect(tracker.childStatuses, isEmpty);
    });

    test("merges a bounded deferred snapshot when child startup fails", () {
      expect(mapper.map(_toolCall(toolCallId: "failed-call", title: "subagent")), isEmpty);
      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "root",
              "update": {
                "sessionUpdate": "tool_call_update",
                "toolCallId": "failed-call",
                "status": "in_progress",
                "content": [
                  {
                    "type": "content",
                    "content": {"type": "text", "text": "startup detail"},
                  },
                ],
              },
            },
          ),
        ),
        isEmpty,
      );
      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "root",
              "update": {
                "sessionUpdate": "tool_call_update",
                "toolCallId": "failed-call",
                "title": "Delegation startup",
              },
            },
          ),
        ),
        isEmpty,
      );
      for (var index = 0; index < 256; index += 1) {
        expect(
          mapper.map(
            AcpNotification(
              method: AcpMethods.sessionUpdate,
              params: {
                "sessionId": "root",
                "update": {
                  "sessionUpdate": "tool_call_update",
                  "toolCallId": "failed-call",
                  "futureField-$index": index,
                },
              },
            ),
          ),
          isEmpty,
        );
      }

      final events = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "tool_call_update",
              "toolCallId": "failed-call",
              "status": "failed",
              "rawOutput": "terminal failure",
            },
          },
        ),
      );
      final tools = events
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartTool>()
          .toList(growable: false);
      expect(tools, hasLength(1));
      expect(tools.single.state.status, PluginToolStatus.error);
      expect(tools.last.state.output, "terminal failure");
      expect(tools.last.state.title, "Delegation startup");
      expect(tools.last.state.error, "terminal failure");
    });

    test("later structured content replaces stale deferred raw output", () {
      expect(mapper.map(_toolCall(toolCallId: "failed-call", title: "subagent")), isEmpty);
      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "root",
              "update": {
                "sessionUpdate": "tool_call_update",
                "toolCallId": "failed-call",
                "rawOutput": "stale progress",
              },
            },
          ),
        ),
        isEmpty,
      );

      final events = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "tool_call_update",
              "toolCallId": "failed-call",
              "status": "failed",
              "content": <Object?>[],
            },
          },
        ),
      );
      final terminal = events.whereType<BridgeSseMessagePartUpdated>().last.part as PluginMessagePartTool;
      expect(terminal.state.status, PluginToolStatus.error);
      expect(terminal.state.output, isNull);
      expect(terminal.state.error, isNull);
    });

    test("a malformed start releases its deferred generic delegation card", () {
      expect(mapper.map(_toolCall(toolCallId: "call", title: "subagent")), isEmpty);

      final events = mapper.map(
        const AcpNotification(
          method: DeepSeekAcpApi.subagentMethod,
          params: {
            "kind": "started",
            "sessionId": "root",
            "childSessionId": "child",
            "toolCallId": "call",
            "prompt": "Inspect the synthetic module",
            "label": "",
            "mode": "foreground",
          },
        ),
      );

      expect(events.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartTool>());
      expect(tracker.childStatuses, isEmpty);
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

    test("a lifecycle prompt ignores child user-message echoes", () {
      mapper.map(_started(mode: "foreground"));

      expect(
        mapper.map(
          const AcpNotification(
            method: AcpMethods.sessionUpdate,
            params: {
              "sessionId": "child",
              "update": {
                "sessionUpdate": "user_message_chunk",
                "messageId": "launch-prompt",
                "content": {"type": "text", "text": "Inspect the synthetic module"},
              },
            },
          ),
        ),
        isEmpty,
      );
      final ended = mapper.map(_ended(reason: "completed", summary: "Done"));
      final tile = ended.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartSubtask;
      expect(tile.prompt, "Inspect the synthetic module");
    });

    test("a nested child renders in its direct parent while activity rolls up to root", () {
      mapper.map(_started(mode: "foreground"));

      final nested = mapper.map(
        _startedWithIdentity(
          parentSessionId: "child",
          mode: "background",
          childSessionId: "grandchild",
          toolCallId: "nested-call",
        ),
      );

      final session = nested.whereType<BridgeSseSessionCreated>().single.info;
      expect(session["parentID"], "child");
      expect(tracker.childSessions(sessionId: "root", directory: "/project").map((child) => child.id), [
        "child",
      ]);
      expect(tracker.childSessions(sessionId: "child", directory: "/project").map((child) => child.id), [
        "grandchild",
      ]);
      final envelope = nested.whereType<BridgeSseMessageUpdated>().single.info;
      expect(envelope["id"], "child-subagent-grandchild");
      expect(envelope["sessionID"], "child");
      final tile = nested.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartSubtask;
      expect(tile.sessionID, "child");
      expect(tile.id, "child-subagent-grandchild-subtask");
      expect(tracker.busyChildIds(sessionId: "root"), {"child", "grandchild"});

      final updated = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "grandchild",
            "update": {"sessionUpdate": "session_info_update", "title": "Nested"},
          },
        ),
      );
      expect(updated.whereType<BridgeSseSessionUpdated>().single.info["parentID"], "child");
    });

    test("child standard updates inherit the root model and provider selection", () {
      configurationTracker.setSessionOverride(
        sessionId: "root",
        modelId: "deepseek-chat",
        providerId: "deepseek",
      );
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
      expect(message["modelID"], "deepseek-chat");
      expect(message["providerID"], "deepseek");
      final text = events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartText;
      expect(text.sessionID, "child");
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "Child reply");
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

    test("a duplicate start refreshes the child's corrected root project", () {
      mapper.map(_started(mode: "foreground"));
      mapper.setSessionProject("root", "/corrected");

      expect(mapper.map(_started(mode: "foreground")), isEmpty);
      final events = mapper.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "child",
            "update": {"sessionUpdate": "session_info_update", "title": "Updated child"},
          },
        ),
      );

      final child = events.whereType<BridgeSseSessionUpdated>().single.info;
      expect(child["projectID"], "/corrected");
      expect(child["directory"], "/corrected");
    });

    test("a malformed terminal notification errors the child and releases root work", () {
      mapper.map(_started(mode: "foreground"));

      final events = mapper.map(
        const AcpNotification(
          method: DeepSeekAcpApi.subagentMethod,
          params: {
            "kind": "ended",
            "sessionId": "root",
            "childSessionId": "child",
            "stopReason": "completed",
            "summary": null,
          },
        ),
      );

      final tile = (events.first as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(tile.taskState?.status, PluginToolStatus.error);
      expect(tile.taskState?.error, "DeepSeek sub-agent returned an invalid completion");
      expect((events.last as BridgeSseSessionStatus).status["type"], "idle");
      expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("astral terminal summaries remain valid and release root work", () {
      final summary = List.filled(300, "😀").join();
      mapper.map(_started(mode: "foreground"));

      final events = mapper.map(_ended(reason: "completed", summary: summary));

      final tile = (events.first as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(tile.taskState?.output, summary);
      expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
    });

    test("replay terminal summaries use the same 500-scalar bound as live tiles", () {
      const subagentMapper = DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id);
      final summary = List.filled(512, "😀").join();

      final completed = subagentMapper.mapState(
        stopReason: DeepSeekSubagentStopReason.completed,
        summary: summary,
      );
      final failed = subagentMapper.mapState(
        stopReason: DeepSeekSubagentStopReason.error,
        summary: summary,
      );

      expect(completed.output?.runes.length, maxToolOutputLength);
      expect(failed.error?.runes.length, maxToolOutputLength);
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

AcpNotification _toolUpdate({required String toolCallId, required String status}) => AcpNotification(
  method: AcpMethods.sessionUpdate,
  params: {
    "sessionId": "root",
    "update": {"sessionUpdate": "tool_call_update", "toolCallId": toolCallId, "status": status},
  },
);

AcpNotification _started({required String mode}) => _startedWithIdentity(
  parentSessionId: "root",
  mode: mode,
  childSessionId: "child",
  toolCallId: "call",
);

AcpNotification _startedWithIdentity({
  required String parentSessionId,
  required String mode,
  required String childSessionId,
  required String toolCallId,
}) => AcpNotification(
  method: DeepSeekAcpApi.subagentMethod,
  params: {
    "kind": "started",
    "sessionId": parentSessionId,
    "childSessionId": childSessionId,
    "toolCallId": toolCallId,
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
