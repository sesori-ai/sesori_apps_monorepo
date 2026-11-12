import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_event_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_sub_agent_item_parser.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:test/test.dart";

// Fixtures mirror the codex-cli 0.148.0 app-server frames captured in
// .plan/completed/claude-inline-subtasks/followups/codex-probe.md (ids redacted).
CodexSubAgentActivity activityOf(CodexSubAgentActivity? event) =>
    event ?? fail("expected CodexSubAgentActivity, got null");

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
      expect(activity.model, isNull);
      expect(activity.reasoningEffort, isNull);
    });

    test("reads the resolved model and effort codex-cli 0.167 adds to a started activity", () {
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
              "model": "gpt-5.6-codex-mini",
              "reasoningEffort": "low",
            },
            "threadId": "parent-1",
            "turnId": "turn-1",
          },
        ),
      );

      final activity = activityOf(event);
      expect(activity.model, "gpt-5.6-codex-mini");
      expect(activity.reasoningEffort, "low");
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

  group("collabAgentToolCall (multi_agent_v1)", () {
    CodexServerNotification collab({
      required String method,
      required String tool,
      required List<String> receiverThreadIds,
    }) => CodexServerNotification(
      method: method,
      params: {
        "item": {
          "type": "collabAgentToolCall",
          "id": "call_spawn",
          "tool": tool,
          "status": "completed",
          "senderThreadId": "parent-1",
          "receiverThreadIds": receiverThreadIds,
          "prompt": "Reply with exactly: done",
          "model": "test-oai",
          "reasoningEffort": "low",
          "agentsStates": <String, Object?>{},
        },
        "threadId": "parent-1",
        "turnId": "turn-1",
      },
    );

    test("treats a completed spawnAgent call as the child's start", () {
      final activity = activityOf(
        parser.parse(
          notification: collab(method: "item/completed", tool: "spawnAgent", receiverThreadIds: ["child-1"]),
        ),
      );
      expect(activity.lifecycle, CodexCorrelatableItemLifecycle.started);
      expect(activity.kind, CodexSubAgentActivityKind.started);
      expect(activity.threadId, "parent-1");
      expect(activity.turnId, "turn-1");
      expect(activity.itemId, "call_spawn");
      expect(activity.agentThreadId, "child-1");
      expect(activity.agentPath, isNull);
      expect(activity.model, "test-oai");
      expect(activity.reasoningEffort, "low");
    });

    test("ignores a started spawn, wait calls, and spawns without a child", () {
      expect(
        parser.parse(
          notification: collab(method: "item/started", tool: "spawnAgent", receiverThreadIds: []),
        ),
        isNull,
      );
      expect(
        parser.parse(
          notification: collab(method: "item/completed", tool: "wait", receiverThreadIds: ["child-1"]),
        ),
        isNull,
      );
      expect(
        parser.parse(
          notification: collab(method: "item/completed", tool: "spawnAgent", receiverThreadIds: []),
        ),
        isNull,
      );
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
