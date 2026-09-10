import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_sub_agent_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_sub_agent_rollout_fact.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  test("tracker uses exact matching spawn text until initial child plaintext replaces it", () {
    final tracker = CodexSubAgentTracker();
    final child = _child(id: "child-1", parentId: "root-1", nickname: "Raman");
    tracker.record(child: child);
    tracker.observeSpawn(
      parentId: "root-1",
      fact: const CodexSubAgentSpawnFact(
        callId: "other-call",
        agent: "reviewer",
        message: "Wrong task.",
      ),
    );
    tracker.observeSpawn(
      parentId: "root-1",
      fact: const CodexSubAgentSpawnFact(
        callId: "call-spawn",
        agent: "worker",
        message: "  Exact delegated task.  ",
      ),
    );

    final fallback = tracker.observeStarted(child: child, callId: "call-spawn");
    expect(fallback?.prompt, "  Exact delegated task.  ");
    expect(fallback?.agent, "worker");
    tracker.observeTurnStarted(childId: child.id, turnId: "initial-turn");
    final plaintext = tracker.observeInitialInput(
      childId: child.id,
      fact: const CodexSubAgentInitialInputFact(
        turnId: "initial-turn",
        input: CodexSubAgentPlaintextInput(message: "Child-owned plaintext."),
      ),
    );
    expect(plaintext?.prompt, "Child-owned plaintext.");
    expect(
      tracker.observeInitialInput(
        childId: child.id,
        fact: const CodexSubAgentInitialInputFact(
          turnId: "resumed-turn",
          input: CodexSubAgentPlaintextInput(message: "Later input."),
        ),
      ),
      isNull,
    );
    expect(
      tracker.finish(childId: child.id, status: PluginToolStatus.completed, turnId: "resumed-turn"),
      isNull,
    );
    expect(
      tracker.finish(childId: child.id, status: PluginToolStatus.completed, turnId: "initial-turn")?.status,
      PluginToolStatus.completed,
    );
    expect(
      tracker.finish(childId: child.id, status: PluginToolStatus.cancelled, turnId: null),
      isNull,
      reason: "first terminal wins across close or disconnect cleanup",
    );
  });

  test("native nested activities replace same-description spawns only by exact call id", () {
    final repository = _repository();
    final messages = repository.projectMessages(
      read: CodexPreparedMessageRead(
        lines: [
          _spawn(callId: "call-a", prompt: "Same task."),
          _spawn(callId: "call-b", prompt: "Same task."),
          _activity(callId: "call-b", childId: "child-b"),
          _activity(callId: "call-a", childId: "child-a"),
          _spawnResult(callId: "call-a"),
          _spawnResult(callId: "call-b"),
        ],
      ),
      sessionId: "root-1",
      children: [
        _child(id: "child-a", parentId: "root-1", nickname: "Raman"),
        _child(id: "child-b", parentId: "root-1", nickname: "Hooke"),
      ],
      replayToolDisposition: CodexReplayToolDisposition.terminalize,
      structuredToolStatusByCallId: const {},
      childReplayDataById: const {
        "child-a": CodexSubAgentReplayData(
          initialTurnId: "turn-a",
          initialInput: CodexSubAgentInitialInputFact(
            turnId: "turn-a",
            input: CodexSubAgentEncryptedInput(),
          ),
          terminalStatus: PluginToolStatus.completed,
        ),
        "child-b": CodexSubAgentReplayData(
          initialTurnId: "turn-b",
          initialInput: CodexSubAgentInitialInputFact(
            turnId: "turn-b",
            input: CodexSubAgentEncryptedInput(),
          ),
          terminalStatus: PluginToolStatus.error,
        ),
      },
    );

    final tasks = messages.expand((message) => message.parts).whereType<PluginMessagePartSubtask>().toList();
    expect(tasks, hasLength(2));
    expect(tasks.singleWhere((task) => task.childSessionID == "child-a").id, "call-a-tool");
    expect(tasks.singleWhere((task) => task.childSessionID == "child-b").id, "call-b-tool");
    expect(tasks.every((task) => task.prompt == "Same task."), isTrue);
    expect(tasks.singleWhere((task) => task.childSessionID == "child-a").taskState?.status, PluginToolStatus.completed);
    expect(tasks.singleWhere((task) => task.childSessionID == "child-b").taskState?.status, PluginToolStatus.error);
    expect(messages.expand((message) => message.parts).whereType<PluginMessagePartTool>(), isEmpty);
  });

  test("child replay trims copied prefix and binds plaintext plus first terminal to initial turn", () {
    final repository = _repository();
    final lines = [
      _metadata(id: "child-1", parentId: "root-1"),
      _metadata(id: "root-1", parentId: null),
      _taskStarted(turnId: "copied-parent-turn"),
      _line(type: "event_msg", payload: {"type": "user_message", "message": "Parent history."}),
      _taskStarted(turnId: "initial-child-turn"),
      ..._initialInput(
        turnId: "initial-child-turn",
        author: "/root",
        recipient: "/root/worker",
        plaintextPayload: "Child plaintext task.",
      ),
      _taskCompleted(turnId: "initial-child-turn", failed: true),
      _taskStarted(turnId: "resumed-turn"),
      ..._initialInput(
        turnId: "resumed-turn",
        author: "/root",
        recipient: "/root/worker",
        plaintextPayload: "Later task.",
      ),
      _taskCompleted(turnId: "resumed-turn", failed: false),
      _line(type: "event_msg", payload: {"type": "turn_aborted", "turn_id": null}),
    ];
    final replay = repository.subAgentReplayData(
      read: CodexPreparedMessageRead(
        lines: CodexMessageRepository.trimForkedParentHistory(lines: lines),
      ),
    );

    expect(replay.initialTurnId, "initial-child-turn");
    expect((replay.initialInput!.input as CodexSubAgentPlaintextInput).message, "Child plaintext task.");
    expect(replay.terminalStatus, PluginToolStatus.error);
  });

  for (final terminal in [
    (line: _taskCompleted(turnId: "initial", failed: false), status: PluginToolStatus.completed),
    (line: _taskCompleted(turnId: "initial", failed: true), status: PluginToolStatus.error),
    (
      line: _line(type: "event_msg", payload: {"type": "turn_aborted", "turn_id": "initial"}),
      status: PluginToolStatus.cancelled,
    ),
  ]) {
    test("replay keeps initial ${terminal.status.name} after resumed completion", () {
      final replay = _repository().subAgentReplayData(
        read: CodexPreparedMessageRead(
          lines: [
            _taskStarted(turnId: "initial"),
            terminal.line,
            _taskStarted(turnId: "resumed"),
            _taskCompleted(turnId: "resumed", failed: false),
          ],
        ),
      );
      expect(replay.terminalStatus, terminal.status);
    });
  }

  test("encrypted child input stays opaque and malformed plaintext envelope is ignored", () {
    final repository = _repository();
    final encrypted = _initialInput(
      turnId: "turn-1",
      author: "/root",
      recipient: "/root/worker",
      plaintextPayload: null,
    );
    final encryptedFact = repository.subAgentRolloutFact(line: encrypted.last, previousLine: encrypted.first);
    expect((encryptedFact! as CodexSubAgentInitialInputFact).input, isA<CodexSubAgentEncryptedInput>());

    final malformed = _line(
      type: "response_item",
      payload: {
        "type": "agent_message",
        "id": "amsg-2",
        "author": "/root",
        "recipient": "/root/worker",
        "content": [
          {"type": "input_text", "text": "Message Type: NEW_TASK\nPayload:\nDo not trust this."},
        ],
        "internal_chat_message_metadata_passthrough": {"turn_id": "turn-1"},
      },
    );
    expect(repository.subAgentRolloutFact(line: malformed, previousLine: encrypted.first), isNull);
  });

  test("spawn without matching native activity remains generic", () {
    final messages = _repository().projectMessages(
      read: CodexPreparedMessageRead(
        lines: [_spawn(callId: "call-spawn", prompt: "Never started.")],
      ),
      sessionId: "root-1",
      children: const [],
      replayToolDisposition: CodexReplayToolDisposition.terminalize,
      structuredToolStatusByCallId: const {},
      childReplayDataById: const {},
    );

    expect(messages.single.parts.single, isA<PluginMessagePartTool>());
  });

  test("cold plugin replay uses matching spawn fallback for encrypted child input", () async {
    final home = Directory.systemTemp.createTempSync("codex-inline-");
    addTearDown(() => home.deleteSync(recursive: true));
    final sessions = Directory("${home.path}/sessions")..createSync();
    const parentId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
    const childId = "019a0000-1111-2222-3333-aaaaaaaaaaab";
    _writeRollout(
      directory: sessions,
      id: parentId,
      records: [
        _metadataJson(id: parentId, parentId: null),
        _spawnJson(callId: "call-spawn", prompt: "Review architecture."),
        _activityJson(callId: "call-spawn", childId: childId),
        _spawnResultJson(callId: "call-spawn"),
      ],
    );
    _writeRollout(
      directory: sessions,
      id: childId,
      records: [
        _metadataJson(id: childId, parentId: parentId),
        _rawLine(type: "event_msg", payload: {"type": "task_started", "turn_id": "child-turn"}),
        ..._initialInputJson(
          turnId: "child-turn",
          author: "/root",
          recipient: "/root/worker",
          plaintextPayload: null,
        ),
        _rawLine(type: "event_msg", payload: {"type": "task_complete", "turn_id": "child-turn", "error": null}),
      ],
    );
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:0",
      environment: {"CODEX_HOME": home.path},
      projectCwd: "/repo",
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
    );
    addTearDown(plugin.dispose);

    final task = (await plugin.getSessionMessages(parentId)).single.parts.single as PluginMessagePartSubtask;
    expect(task.childSessionID, childId);
    expect(task.prompt, "Review architecture.");
    expect(task.prompt, isNot(contains("Message Type:")));
    expect(task.taskState?.status, PluginToolStatus.completed);
  });
}

CodexMessageRepository _repository() => CodexMessageRepository(
  rolloutApi: CodexRolloutApi(environment: const {}),
  rolloutToolMapper: const CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper()),
  userContentMapper: const CodexUserContentMapper(),
);

CodexThreadRecord _child({required String id, required String parentId, required String? nickname}) =>
    CodexThreadRecord(
      id: id,
      name: null,
      directory: "/repo",
      createdAt: null,
      updatedAt: null,
      model: null,
      modelProvider: null,
      parentId: parentId,
      agentNickname: nickname,
      agentPath: "/root/worker",
    );

CodexRolloutLineDto _spawn({required String callId, required String prompt}) =>
    CodexRolloutLineDto.fromJson(_spawnJson(callId: callId, prompt: prompt));

Map<String, Object?> _spawnJson({required String callId, required String prompt}) => _rawLine(
  type: "response_item",
  payload: {
    "type": "function_call",
    "call_id": callId,
    "name": "spawn_agent",
    "arguments": jsonEncode({"task_name": "same", "message": prompt, "agent_type": "worker"}),
    "internal_chat_message_metadata_passthrough": {"turn_id": "parent-turn"},
  },
);

CodexRolloutLineDto _activity({required String callId, required String childId}) =>
    CodexRolloutLineDto.fromJson(_activityJson(callId: callId, childId: childId));

Map<String, Object?> _activityJson({required String callId, required String childId}) => _rawLine(
  type: "event_msg",
  payload: {
    "type": "item_completed",
    "thread_id": "root-1",
    "turn_id": "parent-turn",
    "item": {
      "type": "SubAgentActivity",
      "id": callId,
      "kind": "started",
      "agent_thread_id": childId,
      "agent_path": "/root/worker",
    },
  },
);

CodexRolloutLineDto _spawnResult({required String callId}) =>
    CodexRolloutLineDto.fromJson(_spawnResultJson(callId: callId));

Map<String, Object?> _spawnResultJson({required String callId}) => _rawLine(
  type: "response_item",
  payload: {"type": "function_call_output", "call_id": callId, "output": "{}"},
);

CodexRolloutLineDto _metadata({required String id, required String? parentId}) =>
    CodexRolloutLineDto.fromJson(_metadataJson(id: id, parentId: parentId));

Map<String, Object?> _metadataJson({required String id, required String? parentId}) => _rawLine(
  type: "session_meta",
  payload: {
    "id": id,
    "cwd": "/repo",
    if (parentId != null) ...{
      "parent_thread_id": parentId,
      "thread_source": "subagent",
      "agent_nickname": "Raman",
      "agent_path": "/root/worker",
    },
  },
);

CodexRolloutLineDto _taskStarted({required String turnId}) =>
    _line(type: "event_msg", payload: {"type": "task_started", "turn_id": turnId});

CodexRolloutLineDto _taskCompleted({required String turnId, required bool failed}) => _line(
  type: "event_msg",
  payload: {
    "type": "task_complete",
    "turn_id": turnId,
    "error": failed ? {"message": "failed"} : null,
  },
);

List<CodexRolloutLineDto> _initialInput({
  required String turnId,
  required String author,
  required String recipient,
  required String? plaintextPayload,
}) => [
  for (final json in _initialInputJson(
    turnId: turnId,
    author: author,
    recipient: recipient,
    plaintextPayload: plaintextPayload,
  ))
    CodexRolloutLineDto.fromJson(json),
];

List<Map<String, Object?>> _initialInputJson({
  required String turnId,
  required String author,
  required String recipient,
  required String? plaintextPayload,
}) => [
  _rawLine(type: "inter_agent_communication_metadata", payload: {"trigger_turn": true}),
  _rawLine(
    type: "response_item",
    payload: {
      "type": "agent_message",
      "id": "amsg-$turnId",
      "author": author,
      "recipient": recipient,
      "content": plaintextPayload == null
          ? [
              {
                "type": "input_text",
                "text": "Message Type: NEW_TASK\nTask name: $recipient\nSender: $author\nPayload:\n",
              },
              {"type": "encrypted_content", "encrypted_content": "opaque"},
            ]
          : [
              {
                "type": "input_text",
                "text": "Message Type: NEW_TASK\nTask name: $recipient\nSender: $author\nPayload:\n$plaintextPayload",
              },
            ],
      "internal_chat_message_metadata_passthrough": {"turn_id": turnId},
    },
  ),
];

CodexRolloutLineDto _line({required String type, required Map<String, Object?> payload}) =>
    CodexRolloutLineDto.fromJson(_rawLine(type: type, payload: payload));

Map<String, Object?> _rawLine({required String type, required Map<String, Object?> payload}) => {
  "timestamp": "2026-09-05T12:00:00Z",
  "type": type,
  "payload": payload,
};

void _writeRollout({required Directory directory, required String id, required List<Map<String, Object?>> records}) {
  File("${directory.path}/rollout-2026-09-05T12-00-00-$id.jsonl")
      .writeAsStringSync("${records.map(jsonEncode).join("\n")}\n");
}
