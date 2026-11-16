import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/models/grok_session_notification_dto.dart";
import "package:grok_plugin/src/repositories/mappers/grok_session_replay_collector.dart";
import "package:grok_plugin/src/repositories/models/grok_session_replay_context.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap;
import "package:test/test.dart";

void main() {
  late AcpReplayCollector collector;
  late GrokSessionReplayCollector replayCollector;

  AcpNotification standard({required Map<String, dynamic> update}) => AcpNotification(
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

  void createCollector({required Map<String, String> prompts}) {
    collector = AcpReplayCollector(
      sessionUpdateNormalizer: null,
      shellCommandResolver: null,
      toolNameResolver: null,
      sessionId: "root",
      agentId: "grok",
      initialUserMessage: null,
      messageIdOverride: null,
      messageTimeResolver: null,
      haltClassifier: null,
      toolPartReplacement: null,
      toolPartSuppression: GrokSessionProtocol.isSpawnSubagentUpdate,
      separatesToolMessages: false,
    );
    replayCollector = GrokSessionReplayCollector(
      sessionId: "root",
      standardCollector: collector,
      context: GrokSessionReplayContext(childPrompts: prompts),
    );
  }

  Map<String, dynamic> spawned({required String childId, required String description}) => {
    "sessionUpdate": "subagent_spawned",
    "subagent_id": childId,
    "child_session_id": childId,
    "subagent_type": "general-purpose",
    "description": description,
  };

  Map<String, dynamic> finished({
    required String childId,
    required String status,
    required String? output,
    required String? error,
  }) => {
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

  setUp(
    () => createCollector(prompts: const {"child-a": "Prompt A", "child-b": "Prompt B"}),
  );

  test("suppresses typed spawn card and inserts one terminal tile in wire order", () {
    replayCollector
      ..consumeNotification(
        notification: standard(
          update: {
            "sessionUpdate": "user_message_chunk",
            "content": {"type": "text", "text": "Root prompt"},
          },
        ),
      )
      ..consumeNotification(
        notification: standard(
          update: {
            "sessionUpdate": "tool_call",
            "toolCallId": "spawn-call",
            "_meta": {
              "x.ai/tool": {"name": "spawn_subagent", "kind": "task"},
            },
          },
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned(childId: "child-a", description: "Child A"),
        ),
      )
      ..consumeNotification(
        notification: standard(
          update: {
            "sessionUpdate": "tool_call",
            "toolCallId": "ordinary-call",
            "title": "Read file",
            "status": "completed",
          },
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: finished(
            childId: "child-a",
            status: "completed",
            output: "Result A",
            error: null,
          ),
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
    expect(tile.taskState?.status, PluginToolStatus.completed);
    expect(tile.taskState?.output, "Result A");
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
          update: spawned(childId: "child-a", description: "Same description"),
        ),
      )
      ..consumeNotification(
        notification: standard(
          update: {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "Between"},
          },
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: spawned(childId: "child-b", description: "Same description"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: finished(
            childId: "child-b",
            status: "cancelled",
            output: null,
            error: "Cancelled",
          ),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned(childId: "child-b", description: "Duplicate"),
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
    final lastTaskState = tiles.last.taskState ?? fail("child-b tile has no task state");
    expect(lastTaskState.status, PluginToolStatus.cancelled);
    expect(lastTaskState.error, isNull);
  });

  test("missing child prompt or description never fabricates a tile", () {
    createCollector(prompts: const {"child-a": "Prompt A"});
    replayCollector
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned(childId: "child-missing", description: "Missing prompt"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.updateMethod,
          update: spawned(childId: "child-a", description: ""),
        ),
      );

    expect(build(), isEmpty);
  });

  test("foreign methods are ignored and late post-build notification settles original tile", () {
    replayCollector.consumeNotification(
      notification: lifecycle(
        method: GrokSessionProtocol.updateMethod,
        update: spawned(childId: "child-a", description: "Child A"),
      ),
    );
    expect(
      build().single.parts.single,
      isA<PluginMessagePartSubtask>().having((part) => part.taskState?.status, "status", PluginToolStatus.running),
    );

    replayCollector
      ..consumeNotification(
        notification: lifecycle(
          method: "foreign/method",
          update: finished(childId: "child-a", status: "failed", output: null, error: "ignored"),
        ),
      )
      ..consumeNotification(
        notification: lifecycle(
          method: GrokSessionProtocol.notificationMethod,
          update: finished(childId: "child-a", status: "failed", output: null, error: "Failure"),
        ),
      );

    final tile = build().single.parts.single as PluginMessagePartSubtask;
    expect(tile.taskState?.status, PluginToolStatus.error);
    expect(tile.taskState?.error, "Failure");
  });

  group("compaction rows from recorded replay", () {
    const root = "01a00000-0000-7000-8000-000000000001";

    List<AcpNotification> frames({required String name}) => [
      for (final frame in jsonDecodeListMap(File("test/fixtures/protocol/v1/$name").readAsStringSync()))
        if (frame case {"method": final String method, "params": final Map<String, dynamic> params})
          AcpNotification(method: method, params: params),
    ];

    List<PluginMessageWithParts> replay({required List<AcpNotification> notifications}) {
      final standardCollector = AcpReplayCollector(
        sessionUpdateNormalizer: null,
        shellCommandResolver: null,
        toolNameResolver: null,
        sessionId: root,
        agentId: "grok",
        initialUserMessage: null,
        messageIdOverride: null,
        messageTimeResolver: null,
        haltClassifier: null,
        toolPartReplacement: null,
        toolPartSuppression: GrokSessionProtocol.isSpawnSubagentUpdate,
        separatesToolMessages: false,
      );
      final grokCollector = GrokSessionReplayCollector(
        sessionId: root,
        standardCollector: standardCollector,
        context: GrokSessionReplayContext(childPrompts: const {}),
      );
      for (final notification in notifications) {
        grokCollector.consumeNotification(notification: notification);
      }
      return grokCollector.buildWithAssistantSelection(modelId: null, providerId: null, variant: null);
    }

    PluginCompactionState? compactionOf({required PluginMessageWithParts message}) => switch (message.parts) {
      [PluginMessagePartCompaction(:final compactionState)] => compactionState,
      _ => null,
    };

    test("an automatic compaction sits between its prompt and reply under the live row's id and time", () {
      final messages = replay(notifications: frames(name: "replay_compaction_auto.json"));

      expect(messages.map((message) => message.info), [
        isA<PluginMessageUser>(),
        isA<PluginMessageAssistant>(),
        isA<PluginMessageAssistant>(),
      ]);
      final row = messages[1];
      expect(row.info.id, GrokSessionProtocol.compactionMessageId(sessionId: root, key: "$root-13"));
      expect(row.info.time?.created, 1790000000000);
      expect(
        compactionOf(message: row),
        const PluginCompactionState.completed(summary: null, freedTokens: 21022 - 18671, trigger: .auto),
      );
      expect(compactionOf(message: messages.last), isNull);
    });

    test("a manual compaction follows its /compact under the live row's id", () {
      final messages = replay(notifications: frames(name: "replay_compaction_manual.json"));

      expect(messages, hasLength(2));
      expect(messages.first.info, isA<PluginMessageUser>());
      final row = messages.last;
      expect(
        row.info.id,
        GrokSessionProtocol.compactionMessageId(sessionId: root, key: "00000000-0000-4000-8000-0000000000c1"),
      );
      expect(
        compactionOf(message: row),
        const PluginCompactionState.completed(summary: null, freedTokens: 19992 - 19017, trigger: .manual),
      );
    });

    test("a failed automatic compaction replays as its failure note", () {
      final messages = replay(
        notifications: [
          ...frames(name: "replay_compaction_auto.json").take(2),
          _failedFrame(root: root),
        ],
      );

      expect(compactionOf(message: messages.last), const PluginCompactionState.failed(reason: null));
    });
  });
}

AcpNotification _failedFrame({required String root}) => AcpNotification(
  method: "_x.ai/session/update",
  params: {
    "sessionId": root,
    "update": {"sessionUpdate": "auto_compact_failed", "error": "API error"},
  },
);
