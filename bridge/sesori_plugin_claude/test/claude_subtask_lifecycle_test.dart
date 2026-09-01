import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _session = "session-1";
const _toolUseId = "toolu-agent";
const _agentId = "abea3c20f79258c96";
const _agentInput = {"description": "Say hi", "prompt": "Reply with hi", "subagent_type": "general-purpose"};

/// The exact envelope captured from CLI 2.1.257 (paths elided).
const _notificationText =
    "<task-notification>\n<task-id>$_agentId</task-id>\n<tool-use-id>$_toolUseId</tool-use-id>\n"
    '<output-file>/tmp/x.output</output-file>\n<status>completed</status>\n<summary>Agent "Say hi" finished</summary>\n'
    "<note>A task-notification fires each time this agent stops.</note>\n<result>hi</result>\n"
    "<usage><subagent_tokens>12400</subagent_tokens></usage>\n</task-notification>";

void main() {
  group("stream parsing", () {
    test("parses task frames and the typed tool-use result", () {
      final started = ClaudeStreamMessage.parse({
        "type": "system",
        "subtype": "task_started",
        "session_id": _session,
        "task_id": _agentId,
        "tool_use_id": _toolUseId,
        "description": "Say hi",
        "task_type": "local_agent",
      });
      final notified = ClaudeStreamMessage.parse({
        "type": "system",
        "subtype": "task_notification",
        "session_id": _session,
        "task_id": _agentId,
        "tool_use_id": _toolUseId,
        "status": "stopped",
        "summary": "hi",
      });
      final launched = ClaudeStreamMessage.parse(_launchResultFrame());
      final ordinary = ClaudeStreamMessage.parse({
        "type": "user",
        "session_id": _session,
        "message": {"role": "user", "content": <Object?>[]},
        "tool_use_result": {"type": "text", "file": "..."},
      });

      expect(started, isA<ClaudeTaskStartedMessage>().having((m) => m.taskType, "type", ClaudeTaskType.subAgent));
      expect(
        notified,
        isA<ClaudeTaskNotificationMessage>().having((m) => m.status, "status", ClaudeTaskStatus.stopped),
      );
      expect(
        (launched as ClaudeUserMessage).toolUseResult,
        isA<ClaudeToolUseResultAsyncLaunched>().having((r) => r.agentId, "agentId", _agentId),
      );
      expect((ordinary as ClaudeUserMessage).toolUseResult, isA<ClaudeToolUseResultUnknown>());
    });

    test("parses only a complete leading task-notification envelope", () {
      final parsed = ClaudeTaskNotification.tryParse(_notificationText);
      expect(parsed?.taskId, _agentId);
      expect(parsed?.toolUseId, _toolUseId);
      expect(parsed?.status, ClaudeTaskStatus.completed);
      expect(parsed?.summary, 'Agent "Say hi" finished');
      expect(parsed?.result, "hi");
      expect(ClaudeTaskNotification.tryParse("please explain $_notificationText"), isNull);
      expect(ClaudeTaskNotification.tryParse("<task-notification><task-id>x</task-id></task-notification>"), isNull);
    });
  });

  group("ClaudeToolTracker tasks", () {
    late ClaudeToolTracker tracker;

    setUp(() => tracker = ClaudeToolTracker());

    test("renders a task only once its input names the sub-agent", () {
      final started = tracker.start(
        sessionId: _session,
        messageId: "msg-1",
        blockIndex: 0,
        toolId: _toolUseId,
        name: "Agent",
        input: const <String, Object?>{},
      );
      expect(started.isTask, isTrue);
      expect(started.toPart(sessionId: _session), isNull);

      final complete = _upsertAgent(tracker);
      expect(
        complete.toPart(sessionId: _session),
        isA<PluginMessagePartSubtask>()
            .having((p) => p.description, "description", "Say hi")
            .having((p) => p.agent, "agent", "general-purpose")
            .having((p) => p.taskState?.status, "status", PluginToolStatus.running)
            .having((p) => p.childSessionID, "child", isNull),
      );
    });

    test("a background task outlives its turn and the notification finalizes it", () {
      _upsertAgent(tracker);
      final launched = tracker.complete(
        sessionId: _session,
        toolId: _toolUseId,
        output: "Async agent launched successfully.",
        isError: false,
        attachments: const [],
        result: const ClaudeToolUseResultAsyncLaunched(agentId: _agentId),
      );
      expect(launched?.state.status, PluginToolStatus.running);
      expect(launched?.childSessionId, "agent-$_agentId");

      tracker.beginTurn(sessionId: _session);
      expect(tracker.runningTaskToolUseIds(sessionId: _session), {_toolUseId});

      final notified = tracker.taskNotified(
        sessionId: _session,
        toolUseId: _toolUseId,
        taskId: _agentId,
        status: ClaudeTaskStatus.completed,
        summary: 'Agent "Say hi" finished',
        result: "hi",
      );
      expect(notified?.state.status, PluginToolStatus.completed);
      expect(notified?.state.output, "hi");
      expect(notified?.messageId, "msg-1");

      final late = tracker.complete(
        sessionId: _session,
        toolId: _toolUseId,
        output: "interrupted",
        isError: true,
        attachments: const [],
        result: const ClaudeToolUseResultAbsent(),
      );
      expect(late?.state.status, PluginToolStatus.completed, reason: "a notification is authoritative");
      expect(tracker.runningTaskToolUseIds(sessionId: _session), isEmpty);
    });

    test("a tool result is a fallback that a later notification replaces", () {
      _upsertAgent(tracker);
      final fallback = tracker.complete(
        sessionId: _session,
        toolId: _toolUseId,
        output: "final report",
        isError: false,
        attachments: const [],
        result: const ClaudeToolUseResultCompleted(agentId: _agentId),
      );
      expect(fallback?.state.status, PluginToolStatus.completed);
      expect(fallback?.state.output, "final report");
      expect(fallback?.childSessionId, "agent-$_agentId");

      final stopped = tracker.taskNotified(
        sessionId: _session,
        toolUseId: _toolUseId,
        taskId: _agentId,
        status: ClaudeTaskStatus.stopped,
        summary: null,
        result: null,
      );
      expect(stopped?.state.status, PluginToolStatus.cancelled);

      final failed = tracker.taskNotified(
        sessionId: _session,
        toolUseId: _toolUseId,
        taskId: _agentId,
        status: ClaudeTaskStatus.failed,
        summary: "boom",
        result: null,
      );
      expect(failed?.state.status, PluginToolStatus.error);
      expect(failed?.state.error, "boom");
      expect(failed?.state.output, isNull);
    });

    test("cancelAll cancels only running tasks and forgets them", () {
      _upsertAgent(tracker);
      tracker.upsertCompleteBlock(
        sessionId: _session,
        messageId: "msg-1",
        blockIndex: 1,
        toolId: "toolu-done",
        name: "Task",
        input: _agentInput,
      );
      tracker.taskNotified(
        sessionId: _session,
        toolUseId: "toolu-done",
        taskId: "other",
        status: ClaudeTaskStatus.completed,
        summary: null,
        result: null,
      );
      expect(tracker.taskStarted(sessionId: _session, toolUseId: "toolu-unknown", taskId: "x"), isNull);

      final cancelled = tracker.cancelAll(sessionId: _session);
      expect(cancelled.map((t) => t.id), [_toolUseId]);
      expect(cancelled.single.state.status, PluginToolStatus.cancelled);
      expect(tracker.task(sessionId: _session, toolUseId: _toolUseId), isNull);
      expect(tracker.cancelAll(sessionId: _session), isEmpty);
    });
  });

  group("ClaudeEventDispatcher subtasks", () {
    late ClaudeEventDispatcher dispatcher;

    setUp(() => dispatcher = ClaudeEventDispatcher(content: const ClaudeContentMapper(), tools: ClaudeToolTracker()));

    test("emits one subtask part through launch, turn end, and notification", () {
      final launch = _map(dispatcher, _agentAssistantFrame());
      expect(launch.whereType<BridgeSseMessageUpdated>(), hasLength(1));
      expect(_subtask(launch).taskState?.status, PluginToolStatus.running);

      final result = _map(dispatcher, _launchResultFrame());
      expect(_subtask(result).childSessionID, "agent-$_agentId");
      expect(_subtask(result).taskState?.status, PluginToolStatus.running);

      dispatcher.completeTurn(sessionId: _session);
      expect(dispatcher.residentTaskToolUseIds(sessionId: _session), {_toolUseId});

      final started = _map(dispatcher, {
        "type": "system",
        "subtype": "task_started",
        "session_id": _session,
        "task_id": _agentId,
        "tool_use_id": _toolUseId,
        "task_type": "local_agent",
      });
      expect(_subtask(started).taskState?.status, PluginToolStatus.running);

      final notified = _map(dispatcher, {
        "type": "system",
        "subtype": "task_notification",
        "session_id": _session,
        "task_id": _agentId,
        "tool_use_id": _toolUseId,
        "status": "completed",
        "summary": "hi",
      });
      expect(notified, hasLength(1));
      expect(_subtask(notified).id, _toolUseId);
      expect(_subtask(notified).messageID, "msg-1");
      expect(_subtask(notified).taskState?.status, PluginToolStatus.completed);
      expect(_subtask(notified).taskState?.output, "hi");
      expect(dispatcher.residentTaskToolUseIds(sessionId: _session), isEmpty);
    });

    test("hides a task-notification text for a known task and keeps an unknown one visible", () {
      _map(dispatcher, _agentAssistantFrame());
      _map(dispatcher, _launchResultFrame());
      dispatcher.completeTurn(sessionId: _session);

      final hidden = _map(dispatcher, _userTextFrame(uuid: "notify-1", text: _notificationText));
      expect(hidden.whereType<BridgeSseMessageUpdated>(), isEmpty);
      expect(_subtask(hidden).taskState?.status, PluginToolStatus.completed);
      expect(_subtask(hidden).taskState?.output, "hi");

      final foreign = _map(
        dispatcher,
        _userTextFrame(uuid: "notify-2", text: _notificationText.replaceAll(_toolUseId, "toolu-elsewhere")),
      );
      expect(foreign.whereType<BridgeSseMessageUpdated>(), hasLength(1));
      expect(foreign.whereType<BridgeSseMessagePartUpdated>().single.part, isA<PluginMessagePartText>());
    });

    test("cancelTasks marks a launched task cancelled after its turn ended", () {
      _map(dispatcher, _agentAssistantFrame());
      _map(dispatcher, _launchResultFrame());
      dispatcher.completeTurn(sessionId: _session);

      final cancelled = dispatcher.cancelTasks(sessionId: _session);
      expect(_subtask(cancelled).taskState?.status, PluginToolStatus.cancelled);
      expect(_subtask(cancelled).messageID, "msg-1");
      expect(dispatcher.cancelTasks(sessionId: _session), isEmpty);
    });
  });

  group("ClaudeHistoryMapper subtasks", () {
    const mapper = ClaudeHistoryMapper(content: ClaudeContentMapper());

    test("replays a finished background agent as one completed subtask and no user bubble", () {
      final messages = mapper.map(
        sessionId: _session,
        records: [
          _agentRecord(),
          _launchResultRecord(),
          _notificationRecord(text: _notificationText),
        ],
        residentTaskToolUseIds: const {},
      );

      expect(messages, hasLength(1));
      final part = messages.single.parts.single as PluginMessagePartSubtask;
      expect(part.id, _toolUseId);
      expect(part.messageID, "msg-1");
      expect(part.taskState?.status, PluginToolStatus.completed);
      expect(part.taskState?.output, "hi");
      expect(part.childSessionID, "agent-$_agentId");
    });

    test("a still-running task is cancelled unless its resident process still runs it", () {
      final dead = mapper.map(
        sessionId: _session,
        records: [_agentRecord(), _launchResultRecord()],
        residentTaskToolUseIds: const {},
      );
      final live = mapper.map(
        sessionId: _session,
        records: [_agentRecord(), _launchResultRecord()],
        residentTaskToolUseIds: const {_toolUseId},
      );

      expect((dead.single.parts.single as PluginMessagePartSubtask).taskState?.status, PluginToolStatus.cancelled);
      expect((live.single.parts.single as PluginMessagePartSubtask).taskState?.status, PluginToolStatus.running);
    });

    test("a foreground result finalizes without a notification and injected records never render", () {
      final messages = mapper.map(
        sessionId: _session,
        records: [
          _agentRecord(),
          _userRecord(
            id: "result-1",
            content: [
              {"type": "tool_result", "tool_use_id": _toolUseId, "content": "final report"},
            ],
            toolUseResult: const ClaudeToolUseResultCompleted(agentId: _agentId),
          ),
          _notificationRecord(text: "<task-notification>malformed"),
        ],
        residentTaskToolUseIds: const {},
      );

      expect(messages, hasLength(1));
      final part = messages.single.parts.single as PluginMessagePartSubtask;
      expect(part.taskState?.status, PluginToolStatus.completed);
      expect(part.taskState?.output, "final report");
      expect(part.childSessionID, "agent-$_agentId");
    });
  });
}

ClaudeTrackedTool _upsertAgent(ClaudeToolTracker tracker) => tracker.upsertCompleteBlock(
  sessionId: _session,
  messageId: "msg-1",
  blockIndex: 0,
  toolId: _toolUseId,
  name: "Agent",
  input: _agentInput,
);

List<BridgeSseEvent> _map(ClaudeEventDispatcher dispatcher, Map<String, Object?> frame) =>
    dispatcher.map(message: ClaudeStreamMessage.parse(frame));

PluginMessagePartSubtask _subtask(List<BridgeSseEvent> events) =>
    events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartSubtask;

Map<String, Object?> _agentAssistantFrame() => {
  "type": "assistant",
  "session_id": _session,
  "uuid": "assistant-frame",
  "message": {
    "id": "msg-1",
    "model": "claude-opus-5",
    "content": [
      {"type": "tool_use", "id": _toolUseId, "name": "Agent", "input": _agentInput},
    ],
  },
};

Map<String, Object?> _launchResultFrame() => {
  "type": "user",
  "session_id": _session,
  "uuid": "launch-result",
  "message": {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": _toolUseId,
        "content": [
          {"type": "text", "text": "Async agent launched successfully."},
        ],
      },
    ],
  },
  "tool_use_result": {"isAsync": true, "status": "async_launched", "agentId": _agentId, "description": "Say hi"},
};

Map<String, Object?> _userTextFrame({required String uuid, required String text}) => {
  "type": "user",
  "session_id": _session,
  "uuid": uuid,
  "message": {"role": "user", "content": text},
};

ClaudeTranscriptAssistantRecord _agentRecord() => const ClaudeTranscriptAssistantRecord(
  id: "msg-1",
  model: "claude-opus-5",
  effort: null,
  content: [
    {"type": "tool_use", "id": _toolUseId, "name": "Agent", "input": _agentInput},
  ],
  cwd: "/tmp/project",
  timestamp: null,
  isSidechain: false,
  gitBranch: null,
  version: null,
  sessionId: _session,
  raw: {},
);

ClaudeTranscriptUserRecord _launchResultRecord() => _userRecord(
  id: "launch-1",
  content: const [
    {"type": "tool_result", "tool_use_id": _toolUseId, "content": "Async agent launched successfully."},
  ],
  toolUseResult: const ClaudeToolUseResultAsyncLaunched(agentId: _agentId),
);

ClaudeTranscriptUserRecord _notificationRecord({required String text}) => _userRecord(
  id: "notify-1",
  content: text,
  toolUseResult: const ClaudeToolUseResultAbsent(),
  isTaskNotification: true,
);

ClaudeTranscriptUserRecord _userRecord({
  required String id,
  required Object? content,
  required ClaudeToolUseResult toolUseResult,
  bool isTaskNotification = false,
}) => ClaudeTranscriptUserRecord(
  id: id,
  content: content,
  isMeta: false,
  isVisibleInTranscriptOnly: false,
  toolUseResult: toolUseResult,
  isTaskNotification: isTaskNotification,
  cwd: "/tmp/project",
  timestamp: null,
  isSidechain: false,
  gitBranch: null,
  version: null,
  sessionId: _session,
  raw: const {},
);
