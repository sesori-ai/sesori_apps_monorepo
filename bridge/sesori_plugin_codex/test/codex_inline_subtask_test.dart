import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_correlatable_item_event_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_dto.dart";
import "package:codex_plugin/src/api/models/codex_sub_agent_item_event_dto.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_tool_lifecycle_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_sub_agent_name_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_tool_part_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_projected_tool.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  const names = CodexSubAgentNameMapper();
  const rolloutMapper = CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper());
  const parts = CodexToolPartMapper();

  test("formats task paths while preserving readable titles and nicknames", () {
    expect(
      names.map(name: null, nickname: null, agentPath: "/root/architecture_review_1271"),
      "Architecture review · 1271",
    );
    expect(names.map(name: "/root/parent/check_ci_2", nickname: null, agentPath: null), "Check ci · 2");
    expect(names.map(name: null, nickname: null, agentPath: "review_api"), "Review api");
    expect(
      names.map(name: "Review API behavior", nickname: null, agentPath: "/root/review_api"),
      "Review API behavior",
    );
    expect(names.map(name: "/root/review_api", nickname: "Raman", agentPath: "/root/review_api"), "Raman");
    expect(names.map(name: null, nickname: null, agentPath: null), isNull);
  });

  for (final activityFirst in [false, true]) {
    test("one navigable subtask survives spawn completion (activity first: $activityFirst)", () {
      final tracker = CodexToolLifecycleTracker(rolloutToolMapper: rolloutMapper);
      final upserts = <PluginMessagePart>[];
      void render({required CodexProjectedTool tool}) => upserts.add(
        parts.map(
          sessionId: "root-1",
          tool: tool,
          children: [_child(nickname: null)],
        ),
      );
      void spawn() {
        for (final tool in tracker.observeRolloutLine(threadId: "root-1", line: _spawn())) {
          render(tool: tool);
        }
      }

      void activity() => render(tool: tracker.observeSubAgentStarted(event: _activity));
      if (activityFirst) {
        activity();
        spawn();
      } else {
        spawn();
        activity();
      }
      for (final line in [_spawnResult(), _parentComplete()]) {
        for (final tool in tracker.observeRolloutLine(threadId: "root-1", line: line)) {
          render(tool: tool);
        }
      }
      expect(upserts.map((part) => part.id).toSet(), {"call-spawn-tool"});
      expect(upserts, everyElement(isA<PluginMessagePartSubtask>()));
      final task = upserts.last as PluginMessagePartSubtask;
      expect(task.childSessionID, "child-1");
      expect(task.description, "Architecture review · 1271");
      expect(task.prompt, "Review the proposed architecture.");
      expect(task.taskState, isNull, reason: "the running child owns status after the parent completes");
    });
  }

  test("activity alone creates a linked card before rollout enrichment is available", () {
    final tracker = CodexToolLifecycleTracker(rolloutToolMapper: rolloutMapper);
    final part = parts.map(
      sessionId: "root-1",
      tool: tracker.observeSubAgentStarted(event: _activity),
      children: [_child(nickname: null)],
    ) as PluginMessagePartSubtask;
    expect(part.childSessionID, "child-1");
    expect(part.description, "Architecture review · 1271");
    expect(part.taskState, isNull);
  });

  test("history resolves the raw task path even when the displayed child nickname differs", () {
    final repository = CodexMessageRepository(
      rolloutApi: CodexRolloutApi(environment: const {}),
      rolloutToolMapper: rolloutMapper,
      userContentMapper: const CodexUserContentMapper(),
    );
    final read = CodexPreparedMessageRead(lines: [_spawn(), _spawnResult(), _parentComplete()]);
    expect(read.hasSubtasks, isTrue);
    final messages = repository.projectMessages(
      read: read,
      sessionId: "root-1",
      children: [_child(nickname: "Raman")],
      replayToolDisposition: CodexReplayToolDisposition.terminalize,
      structuredToolStatusByCallId: const {},
    );
    final task = messages.single.parts.single as PluginMessagePartSubtask;
    expect(task.id, "call-spawn-tool");
    expect(task.description, "Raman");
    expect(task.childSessionID, "child-1");
    expect(task.taskState, isNull);
  });

  test("an interrupted launch without a child retains its explicit failure state", () {
    final repository = CodexMessageRepository(
      rolloutApi: CodexRolloutApi(environment: const {}),
      rolloutToolMapper: rolloutMapper,
      userContentMapper: const CodexUserContentMapper(),
    );
    final messages = repository.projectMessages(
      read: CodexPreparedMessageRead(
        lines: [
          _spawn(),
          _line(
            type: "event_msg",
            payload: {
              "type": "turn_aborted",
              "turn_id": "turn-1",
              "reason": "interrupted",
            },
          ),
        ],
      ),
      sessionId: "root-1",
      children: const [],
      replayToolDisposition: CodexReplayToolDisposition.terminalize,
      structuredToolStatusByCallId: const {},
    );
    final task = messages.single.parts.single as PluginMessagePartSubtask;
    expect(task.childSessionID, isNull);
    expect(task.taskState?.status, PluginToolStatus.error);
  });

  test("a fresh plugin resolves inline history and task-widget titles from persisted metadata", () async {
    final home = Directory.systemTemp.createTempSync("codex-inline-");
    addTearDown(() => home.deleteSync(recursive: true));
    final sessions = Directory("${home.path}/sessions")..createSync();
    const parentId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
    const childId = "019a0000-1111-2222-3333-aaaaaaaaaaab";
    for (final id in [parentId, childId]) {
      final records = [
        {
          "type": "session_meta",
          "payload": {
            "id": id,
            "cwd": "/repo",
            "timestamp": "2026-09-05T12:00:00Z",
            if (id == childId) ...{
              "parent_thread_id": parentId,
              "thread_source": "subagent",
              "agent_path": "/root/architecture_review_1271",
            },
          },
        },
        if (id == parentId) ...[
          {
            "type": "response_item",
            "payload": {
              "type": "function_call",
              "call_id": "call-spawn",
              "name": "spawn_agent",
              "arguments": jsonEncode({"task_name": "architecture_review_1271", "message": "Review the architecture."}),
            },
          },
          {
            "type": "response_item",
            "payload": {
              "type": "function_call_output",
              "call_id": "call-spawn",
              "output": jsonEncode({"task_name": "/root/architecture_review_1271"}),
            },
          },
        ],
      ];
      File("${sessions.path}/rollout-2026-09-05T12-00-00-$id.jsonl")
          .writeAsStringSync("${records.map(jsonEncode).join("\n")}\n");
    }
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:0",
      environment: {"CODEX_HOME": home.path},
      projectCwd: "/repo",
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
    );
    addTearDown(plugin.dispose);
    final messages = await plugin.getSessionMessages(parentId);
    final task = messages.single.parts.single as PluginMessagePartSubtask;
    final children = await plugin.getChildSessions(parentId);
    expect(task.childSessionID, childId);
    expect(task.description, "Architecture review · 1271");
    expect(task.description, children.single.title);
    expect(task.taskState, isNull);
  });
}

const _activity = CodexSubAgentActivity(
  lifecycle: CodexCorrelatableItemLifecycle.started,
  threadId: "root-1",
  turnId: "turn-1",
  itemId: "call-spawn",
  kind: CodexSubAgentActivityKind.started,
  agentThreadId: "child-1",
  agentPath: "/root/architecture_review_1271",
);

CodexThreadRecord _child({required String? nickname}) => CodexThreadRecord(
  id: "child-1",
  name: null,
  directory: "/repo",
  createdAt: null,
  updatedAt: null,
  model: null,
  modelProvider: null,
  parentId: "root-1",
  agentNickname: nickname,
  agentPath: "/root/architecture_review_1271",
);

CodexRolloutLineDto _spawn() => _line(
  type: "response_item",
  payload: {
    "type": "function_call",
    "call_id": "call-spawn",
    "name": "spawn_agent",
    "arguments": jsonEncode({"task_name": "architecture_review_1271", "message": "Review the proposed architecture."}),
    "internal_chat_message_metadata_passthrough": {"turn_id": "turn-1"},
  },
);

CodexRolloutLineDto _spawnResult() => _line(
  type: "response_item",
  payload: {
    "type": "function_call_output",
    "call_id": "call-spawn",
    "output": jsonEncode({"task_name": "/root/architecture_review_1271"}),
  },
);

CodexRolloutLineDto _parentComplete() => _line(
  type: "event_msg",
  payload: {
    "type": "task_complete",
    "turn_id": "turn-1",
    "last_agent_message": "Done",
  },
);

CodexRolloutLineDto _line({required String type, required Map<String, Object?> payload}) =>
    CodexRolloutLineDto.fromJson({
      "timestamp": "2026-09-05T12:00:00Z",
      "type": type,
      "payload": payload,
    });
