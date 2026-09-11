import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/repositories/mappers/cursor_task_projection.dart";
import "package:cursor_plugin/src/repositories/trackers/cursor_task_replay_tracker.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "root";

void main() {
  group("CursorTaskReplayTracker", () {
    test("forwards every notification before replay-local indexing", () {
      final standard = _RecordingReplayCollector();
      final tracker = _tracker(standardCollector: standard);
      const foreign = AcpNotification(method: "cursor/task", params: {"toolCallId": "task-1"});
      final task = _notification(update: _toolCall());

      tracker
        ..consumeNotification(notification: foreign)
        ..consumeNotification(notification: task);
      expect(standard.notifications, [foreign, task]);
    });

    test("preserves completed non-Task generic output without a malformed Task warning", () {
      final update = _toolCall(input: const {"_toolName": "shell"}, status: "completed")
        ..["rawOutput"] = const {"stdout": "done"};
      final notification = _notification(update: update);
      final standard = _collector()..consumeNotification(notification: notification);
      final tracker = _tracker();
      final stderrLines = <String>[];

      IOOverrides.runZoned(
        () => tracker.consumeNotification(notification: notification),
        stderr: () => CapturingStdout(lines: stderrLines),
      );

      expect(stderrLines, isEmpty);
      expect(
        _build(tracker: tracker),
        standard.buildWithAssistantSelection(modelId: "model", providerId: "cursor", variant: "high"),
      );
    });

    test("replaces one complete foreground generic part in order with stable replay identity", () {
      final updates = [
        _text(text: "before"),
        _toolCall(title: "Task: Inspect"),
        _terminal(
          rawOutput: {"durationMs": 42, "isBackground": false},
          content: const [
            {
              "type": "content",
              "content": {"type": "text", "text": "final report"},
            },
            {
              "type": "content",
              "content": {"type": "image", "data": "AA==", "mimeType": "image/png", "uri": null},
            },
          ],
        ),
        _text(text: "after"),
      ];

      final first = _build(tracker: _load(updates: updates));
      final second = _build(tracker: _load(updates: updates));
      expect(second, first, reason: "independent loads use equivalent replay-local fields");
      expect(first.single.parts.map((part) => part.type), [
        PluginMessagePartType.text,
        PluginMessagePartType.subtask,
        PluginMessagePartType.text,
      ]);
      final message = first.single;
      final tile = message.parts[1] as PluginMessagePartSubtask;
      expect((message.info.id, tile.id), ("root-mm1-assistant", "root-mm1-assistant-tool-task-1"));
      expect((tile.sessionID, tile.messageID), (_sessionId, message.info.id));
      expect((tile.prompt, tile.description, tile.agent), ("Inspect code", "Inspect", "unspecified"));
      expect(tile.childSessionID, isNull);
      expect(
        (
          tile.taskState?.status,
          tile.taskState?.title,
          tile.taskState?.output,
          tile.taskState?.attachments.length,
        ),
        (PluginToolStatus.completed, "Task: Inspect", "final report", 1),
      );
      expect(message.parts.whereType<PluginMessagePartTool>(), isEmpty);
    });

    test("merges separately replayed completion and foreground facts", () {
      final updates = [
        _toolCall(),
        {"sessionUpdate": "tool_call_update", "toolCallId": "task-1", "status": "completed"},
        {
          "sessionUpdate": "tool_call_update",
          "toolCallId": "task-1",
          "rawOutput": {"isBackground": false},
        },
      ];
      expect(_build(tracker: _load(updates: updates)).single.parts.single, isA<PluginMessagePartSubtask>());
    });

    test("background, incomplete, malformed, unknown, and nonterminal facts stay generic", () {
      final foreground = {"isBackground": false};
      final cases = <(String, Object, Map<String, dynamic>?)>[
        ("background", _input(), _terminal(rawOutput: {"isBackground": true})),
        ("missing output", _input(), _terminal()),
        ("malformed output", _input(), _terminal(rawOutput: {"isBackground": "false"})),
        ("missing enum", _input(subagentType: const <String, Object?>{}), _terminal(rawOutput: foreground)),
        ("unknown enum", _input(subagentType: const {"custom": "future"}), _terminal(rawOutput: foreground)),
        ("blank prompt", _input(prompt: " "), _terminal(rawOutput: foreground)),
        ("blank description", _input(description: ""), _terminal(rawOutput: foreground)),
        ("malformed input", _input(prompt: 7), _terminal(rawOutput: foreground)),
        ("unknown tool", _input(toolName: "future"), _terminal(rawOutput: foreground)),
        ("pending", _input(), null),
        ("running", _input(), _terminal(status: "in_progress")),
        ("failed", _input(), _terminal(status: "failed")),
        ("unknown status", _input(), _terminal(status: "future")),
      ];

      for (final taskCase in cases) {
        final part = _build(
          tracker: _load(
            updates: [
              _toolCall(input: taskCase.$2, title: taskCase.$1),
              ?taskCase.$3,
            ],
          ),
        ).single.parts.single;
        expect(part, isA<PluginMessagePartTool>(), reason: taskCase.$1);
      }
    });

    test("update-only, unmatched, foreign-session, and absent facts never synthesize tiles", () {
      final updateOnly = _load(
        updates: [
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "task-1",
            "status": "completed",
            "rawInput": _input(),
            "rawOutput": {"isBackground": false},
          },
        ],
      );
      expect(_build(tracker: updateOnly).single.parts.single, isA<PluginMessagePartTool>());

      final unmatched = _load(
        updates: [
          _toolCall(),
          {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "other",
            "status": "completed",
            "rawOutput": {"isBackground": false},
          },
        ],
      );
      expect(_build(tracker: unmatched).expand((message) => message.parts), everyElement(isA<PluginMessagePartTool>()));

      final foreign = _tracker()
        ..consumeNotification(
          notification: _notification(
            update: _toolCall(status: "completed"),
            sessionId: "other",
          ),
        );
      expect(_build(tracker: foreign).single.parts.single, isA<PluginMessagePartTool>());
      expect(_build(tracker: _tracker()), isEmpty, reason: "native cancelled replay absence remains absence");
    });
  });
}

Map<String, dynamic> _input({
  String toolName = "task",
  Object? prompt = "Inspect code",
  Object? description = "Inspect",
  Object? subagentType = const {"custom": "unspecified"},
}) => {
  "_toolName": toolName,
  "prompt": prompt,
  "description": description,
  "subagentType": subagentType,
};

Map<String, dynamic> _toolCall({Object? input, String title = "Task", String status = "pending"}) => {
  "sessionUpdate": "tool_call",
  "toolCallId": "task-1",
  "title": title,
  "status": status,
  "rawInput": input ?? _input(),
  if (status == "completed") "rawOutput": {"isBackground": false},
};

Map<String, dynamic> _terminal({String status = "completed", Object? rawOutput, Object? content}) => {
  "sessionUpdate": "tool_call_update",
  "toolCallId": "task-1",
  "status": status,
  "rawOutput": ?rawOutput,
  "content": ?content,
};

Map<String, dynamic> _text({required String text}) => {
  "sessionUpdate": "agent_message_chunk",
  "messageId": "m1",
  "content": {"type": "text", "text": text},
};

AcpNotification _notification({required Map<String, dynamic> update, String sessionId = _sessionId}) => AcpNotification(
  method: AcpMethods.sessionUpdate,
  params: {"sessionId": sessionId, "update": update},
);

CursorTaskReplayTracker _tracker({AcpReplayCollector? standardCollector}) => CursorTaskReplayTracker(
  sessionId: _sessionId,
  standardCollector: standardCollector ?? _collector(),
  taskProjection: const CursorTaskProjection(),
);

CursorTaskReplayTracker _load({required List<Map<String, dynamic>> updates}) {
  final tracker = _tracker();
  for (final update in updates) {
    tracker.consumeNotification(notification: _notification(update: update));
  }
  return tracker;
}

List<PluginMessageWithParts> _build({required CursorTaskReplayTracker tracker}) => tracker.buildWithAssistantSelection(
  modelId: "model",
  providerId: "cursor",
  variant: "high",
);

AcpReplayCollector _collector() => AcpReplayCollector(
  sessionUpdateNormalizer: null,
  shellCommandResolver: null,
  sessionId: _sessionId,
  agentId: "cursor",
  initialUserMessageId: null,
  messageIdOverride: null,
  messageTimeResolver: null,
  haltClassifier: null,
  toolPartReplacement: null,
  toolPartSuppression: null,
);

final class _RecordingReplayCollector() extends AcpReplayCollector {
  this
    : super(
        sessionUpdateNormalizer: null,
        shellCommandResolver: null,
        sessionId: _sessionId,
        agentId: "cursor",
        initialUserMessageId: null,
        messageIdOverride: null,
        messageTimeResolver: null,
        haltClassifier: null,
        toolPartReplacement: null,
        toolPartSuppression: null,
      );

  final List<AcpNotification> notifications = [];

  @override
  void consumeNotification({required AcpNotification notification}) {
    notifications.add(notification);
    super.consumeNotification(notification: notification);
  }
}
