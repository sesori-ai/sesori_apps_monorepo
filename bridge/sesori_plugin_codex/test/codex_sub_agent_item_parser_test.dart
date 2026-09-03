import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_event_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_sub_agent_item_parser.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:test/test.dart";

// Fixtures mirror the codex-cli 0.148.0 app-server frames captured in
// .plan/completed/claude-inline-subtasks/followups/codex-probe.md (ids redacted).
CodexCollabItem collabOf(CodexSubAgentItemEventDto? event) => switch (event) {
  CodexCollabItem() => event,
  _ => fail("expected CodexCollabItem, got $event"),
};

CodexSubAgentActivity activityOf(CodexSubAgentItemEventDto? event) => switch (event) {
  CodexSubAgentActivity() => event,
  _ => fail("expected CodexSubAgentActivity, got $event"),
};

void main() {
  const parser = CodexSubAgentItemParser();

  group("subAgentActivity", () {
    test("parses the started activity emitted for a spawned child", () {
      final event = parser.parse(
        notification: const CodexServerNotification(
          method: "item/started",
          params: {
            "item": {
              "type": "subAgentActivity",
              "id": "call_spawn",
              "kind": "started",
              "agentThreadId": "child-1",
              "agentPath": "/root/reply_done",
            },
            "threadId": "parent-1",
            "turnId": "turn-1",
            "startedAtMs": 1788356391802,
          },
        ),
      );

      final activity = activityOf(event);
      expect(activity.lifecycle, CodexCorrelatableItemLifecycle.started);
      expect(activity.threadId, "parent-1");
      expect(activity.turnId, "turn-1");
      expect(activity.itemId, "call_spawn");
      expect(activity.kind, CodexSubAgentActivityKind.started);
      expect(activity.agentThreadId, "child-1");
      expect(activity.agentPath, "/root/reply_done");
    });

    test("falls back to an unknown kind and drops an activity without a child id", () {
      final unknownKind = parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "parent-1",
            "item": {
              "type": "subAgentActivity",
              "id": "call_spawn",
              "kind": "paused",
              "agentThreadId": "child-1",
              "agentPath": null,
            },
          },
        ),
      );
      final activity = activityOf(unknownKind);
      expect(activity.kind, CodexSubAgentActivityKind.unknown);
      expect(activity.turnId, isNull);
      expect(activity.agentPath, isNull);

      expect(
        parser.parse(
          notification: const CodexServerNotification(
            method: "item/completed",
            params: {
              "threadId": "parent-1",
              "item": {"type": "subAgentActivity", "id": "call_spawn", "kind": "completed"},
            },
          ),
        ),
        isNull,
      );
    });
  });

  group("collabAgentToolCall", () {
    test("parses the wait item emitted while the parent blocks on a child", () {
      final event = parser.parse(
        notification: const CodexServerNotification(
          method: "item/started",
          params: {
            "item": {
              "type": "collabAgentToolCall",
              "id": "call_wait",
              "tool": "wait",
              "status": "inProgress",
              "senderThreadId": "parent-1",
              "receiverThreadIds": <String>[],
              "prompt": null,
              "model": null,
              "reasoningEffort": null,
              "agentsStates": <String, Object?>{},
            },
            "threadId": "parent-1",
            "turnId": "turn-1",
            "startedAtMs": 1788356394684,
          },
        ),
      );

      final collab = collabOf(event);
      expect(collab.lifecycle, CodexCorrelatableItemLifecycle.started);
      expect(collab.itemId, "call_wait");
      expect(collab.tool, CodexCollabTool.wait);
      expect(collab.status, CodexCollabItemStatus.inProgress);
      expect(collab.senderThreadId, "parent-1");
      expect(collab.receiverThreadIds, isEmpty);
      expect(collab.prompt, isNull);
      expect(collab.agentsStates, isEmpty);
    });

    test("parses a completed spawn with receiver ids, prompt, and agent states", () {
      final event = parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "parent-1",
            "turnId": "turn-1",
            "item": {
              "type": "collabAgentToolCall",
              "id": "call_spawn",
              "tool": "spawnAgent",
              "status": "completed",
              "senderThreadId": "parent-1",
              "receiverThreadIds": ["child-1"],
              "prompt": "reply with the word done",
              "agentsStates": {
                "child-1": {"status": "running", "message": null},
                "child-2": {"status": "notFound", "message": "agent not found"},
                "child-3": {"status": "hibernating", "message": null},
              },
            },
          },
        ),
      );

      final collab = collabOf(event);
      expect(collab.tool, CodexCollabTool.spawnAgent);
      expect(collab.status, CodexCollabItemStatus.completed);
      expect(collab.receiverThreadIds, ["child-1"]);
      expect(collab.prompt, "reply with the word done");
      expect(collab.agentsStates, {
        "child-1": CodexCollabAgentStatus.running,
        "child-2": CodexCollabAgentStatus.notFound,
        "child-3": CodexCollabAgentStatus.unknown,
      });
    });

    test("merges the singular receiver fields into receiverThreadIds", () {
      final event = parser.parse(
        notification: const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "parent-1",
            "turnId": "turn-1",
            "item": {
              "type": "collabAgentToolCall",
              "id": "call_spawn",
              "tool": "spawnAgent",
              "status": "inProgress",
              "senderThreadId": "parent-1",
              "receiverThreadId": "child-1",
              "newThreadId": "child-1",
              "agentsStates": {
                "child-1": {"status": "pendingInit", "message": null},
              },
            },
          },
        ),
      );

      final collab = collabOf(event);
      expect(collab.tool, CodexCollabTool.spawnAgent);
      expect(collab.receiverThreadIds, ["child-1"]);
      expect(collab.agentsStates, {"child-1": CodexCollabAgentStatus.pendingInit});
    });

    test("falls back to unknown tool and status without dropping the item", () {
      final event = parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "parent-1",
            "item": {
              "type": "collabAgentToolCall",
              "id": "call_x",
              "tool": "mergeAgents",
              "status": "paused",
              "receiverThreadIds": ["child-1", 7, " "],
            },
          },
        ),
      );

      final collab = collabOf(event);
      expect(collab.tool, CodexCollabTool.unknown);
      expect(collab.status, CodexCollabItemStatus.unknown);
      expect(collab.senderThreadId, isNull);
      expect(collab.receiverThreadIds, ["child-1"]);
    });
  });

  test("ignores other methods, other item types, and missing identities", () {
    const item = {
      "type": "subAgentActivity",
      "id": "call_spawn",
      "kind": "started",
      "agentThreadId": "child-1",
    };
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/agentMessage/delta",
          params: {"threadId": "parent-1", "item": item},
        ),
      ),
      isNull,
    );
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "parent-1",
            "item": {"type": "commandExecution", "id": "exec-1", "status": "completed"},
          },
        ),
      ),
      isNull,
    );
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {"threadId": " ", "item": item},
        ),
      ),
      isNull,
    );
    expect(
      parser.parse(
        notification: const CodexServerNotification(
          method: "item/completed",
          params: {"threadId": "parent-1", "item": "not-an-object"},
        ),
      ),
      isNull,
    );
  });
}
