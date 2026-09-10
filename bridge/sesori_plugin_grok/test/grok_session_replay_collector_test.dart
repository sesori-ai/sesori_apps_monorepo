import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/models/grok_session_notification_dto.dart";
import "package:grok_plugin/src/repositories/mappers/grok_session_replay_collector.dart";
import "package:grok_plugin/src/repositories/models/grok_session_replay_context.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late AcpReplayCollector collector;
  late GrokSessionReplayCollector replayCollector;

  AcpNotification standard(Map<String, dynamic> update) => AcpNotification(
    method: AcpMethods.sessionUpdate,
    params: {"sessionId": "root", "update": update},
  );

  AcpNotification lifecycle({
    required String method,
    required Map<String, dynamic> update,
  }) => AcpNotification(
    method: method,
    params: {"sessionId": "root", "update": update},
  );

  void createCollector({Map<String, String> prompts = const {"child-a": "Prompt A", "child-b": "Prompt B"}}) {
    collector = AcpReplayCollector(
      sessionUpdateNormalizer: null,
      sessionId: "root",
      agentId: "grok",
      initialUserMessageId: null,
      messageIdOverride: null,
      messageTimeResolver: null,
      haltClassifier: null,
      toolPartReplacement: null,
      toolPartSuppression: GrokSessionProtocol.isSpawnSubagentUpdate,
    );
    replayCollector = GrokSessionReplayCollector(
      sessionId: "root",
      standardCollector: collector,
      context: GrokSessionReplayContext(childPrompts: prompts),
    );
  }

  Map<String, dynamic> spawned(String childId, String description) => {
    "sessionUpdate": "subagent_spawned",
    "subagent_id": childId,
    "child_session_id": childId,
    "subagent_type": "general-purpose",
    "description": description,
  };

  Map<String, dynamic> finished(String childId, String status, {String? output, String? error}) => {
    "sessionUpdate": "subagent_finished",
    "subagent_id": childId,
    "child_session_id": childId,
    "status": status,
    "output": output,
    "error": error,
    "will_wake": false,
  };

  List<PluginMessageWithParts> build() => replayCollector.buildWithAssistantSelection(
    modelId: "model-a",
    providerId: "grok",
    variant: "high",
  );

  setUp(createCollector);

  test("suppresses typed spawn card and inserts one terminal tile in wire order", () {
    replayCollector
      ..consumeNotification(
        notification: standard({
          "sessionUpdate": "user_message_chunk",
          "content": {"type": "text", "text": "Root prompt"},
        }),
      )
      ..consumeNotification(
        notification: standard({
          "sessionUpdate": "tool_call",
          "toolCallId": "spawn-call",
          "_meta": {
            "x.ai/tool": {"name": "spawn_subagent", "kind": "task"},
          },
        }),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned("child-a", "Child A"),
        ),
      )
      ..consumeNotification(
        notification: standard({
          "sessionUpdate": "tool_call",
          "toolCallId": "ordinary-call",
          "title": "Read file",
          "status": "completed",
        }),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: finished("child-a", "completed", output: "Result A"),
        ),
      );

    final messages = build();
    expect(messages, hasLength(3));
    expect(messages.expand((message) => message.parts), hasLength(3));
    expect(messages.expand((message) => message.parts).whereType<PluginMessagePartTool>(), hasLength(1));
    final tile = messages.expand((message) => message.parts).whereType<PluginMessagePartSubtask>().single;
    expect(tile.id, "root-subagent-child-a-subtask");
    expect(tile.messageID, "root-subagent-child-a");
    expect(tile.childSessionID, "child-a");
    expect(tile.prompt, "Prompt A");
    expect(tile.taskState!.status, PluginToolStatus.completed);
    expect(tile.taskState!.output, "Result A");
    expect(messages.every((message) => message.parts.isNotEmpty), isTrue);
    final tileMessage = messages[1].info as PluginMessageAssistant;
    expect(
      (tileMessage.agent, tileMessage.modelID, tileMessage.providerID, tileMessage.variant),
      ("grok", "model-a", "grok", "high"),
    );
  });

  test("multiple children remain ordered and duplicate lifecycle updates retain identity", () {
    replayCollector
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned("child-a", "Same description"),
        ),
      )
      ..consumeNotification(
        notification: standard({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Between"},
        }),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: spawned("child-b", "Same description"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: finished("child-b", "cancelled", error: "Cancelled"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned("child-b", "Duplicate"),
        ),
      );

    final messages = build();
    expect(messages.map((message) => message.info.id), [
      "root-subagent-child-a",
      "root-h0-assistant",
      "root-subagent-child-b",
    ]);
    final tiles = messages.expand((message) => message.parts).whereType<PluginMessagePartSubtask>().toList();
    expect(tiles.map((tile) => tile.childSessionID), ["child-a", "child-b"]);
    expect(tiles.last.taskState!.status, PluginToolStatus.cancelled);
    expect(tiles.last.taskState!.error, isNull);
  });

  test("missing child prompt or description never fabricates a tile", () {
    createCollector(prompts: const {"child-a": "Prompt A"});
    replayCollector
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned("child-missing", "Missing prompt"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned("child-a", ""),
        ),
      );

    expect(build(), isEmpty);
  });

  test("foreign methods are ignored and late post-build notification settles original tile", () {
    replayCollector.consumeNotification(
      notification: lifecycle(
        method: GrokSessionProtocol.updateMethod,
        update: spawned("child-a", "Child A"),
      ),
    );
    expect(
      build().single.parts.single,
      isA<PluginMessagePartSubtask>().having((part) => part.taskState!.status, "status", PluginToolStatus.running),
    );

    replayCollector
      ..consumeNotification(
        notification: lifecycle(
          method: "foreign/method",
          update: finished("child-a", "failed", error: "ignored"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: finished("child-a", "failed", error: "Failure"),
        ),
      );

    final tile = build().single.parts.single as PluginMessagePartSubtask;
    expect(tile.taskState!.status, PluginToolStatus.error);
    expect(tile.taskState!.error, "Failure");
  });
}
