import "dart:convert";

import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_sub_agent_rollout_fact.dart";
import "package:test/test.dart";

void main() {
  final repository = CodexMessageRepository(
    rolloutApi: CodexRolloutApi(environment: const {}),
    rolloutToolMapper: const CodexRolloutToolMapper(
      imageAttachmentMapper: CodexImageAttachmentMapper(),
    ),
    userContentMapper: const CodexUserContentMapper(),
  );

  test("projects exact spawn and nested started-activity facts", () {
    final spawn = repository.subAgentRolloutFact(
      line: _line(
        type: "response_item",
        payload: {
          "type": "function_call",
          "call_id": "call-spawn",
          "name": "spawn_agent",
          "arguments": jsonEncode({
            "agent_type": "worker",
            "message": "  preserve delegated text  ",
          }),
        },
      ),
      previousLine: null,
    );
    if (spawn is! CodexSubAgentSpawnFact) fail("expected a spawn fact, got $spawn");
    final spawnFact = spawn;
    expect(spawnFact.callId, "call-spawn");
    expect(spawnFact.agent, "worker");
    expect(spawnFact.message, "  preserve delegated text  ");

    final started = repository.subAgentRolloutFact(
      line: _line(
        type: "event_msg",
        payload: const {
          "type": "item_completed",
          "thread_id": "parent-1",
          "turn_id": "turn-1",
          "item": {
            "type": "SubAgentActivity",
            "id": "call-spawn",
            "kind": "started",
            "agent_thread_id": "child-1",
            "agent_path": "/root/worker",
          },
        },
      ),
      previousLine: null,
    );
    if (started is! CodexSubAgentStartedActivityFact) fail("expected a started activity fact, got $started");
    final startedFact = started;
    expect(startedFact.callId, "call-spawn");
    expect(startedFact.childThreadId, "child-1");
  });

  test("projects a completed multi_agent_v1 spawn call as the child's start", () {
    CodexSubAgentRolloutFact? collab({required String tool, required List<String> receivers}) =>
        repository.subAgentRolloutFact(
          line: _line(
            type: "event_msg",
            payload: {
              "type": "item_completed",
              "thread_id": "parent-1",
              "turn_id": "turn-1",
              "item": {
                "type": "CollabAgentToolCall",
                "id": "call-spawn",
                "tool": tool,
                "status": "completed",
                "sender_thread_id": "parent-1",
                "receiver_thread_ids": receivers,
                "receiver_agents": [
                  for (final receiver in receivers) {"thread_id": receiver, "agent_nickname": "Darwin"},
                ],
              },
            },
          ),
          previousLine: null,
        );

    final started = collab(tool: "spawn_agent", receivers: ["child-1"]);
    if (started is! CodexSubAgentStartedActivityFact) fail("expected a started activity fact, got $started");
    final startedFact = started;
    expect(startedFact.callId, "call-spawn");
    expect(startedFact.childThreadId, "child-1");
    expect(collab(tool: "wait", receivers: ["child-1"]), isNull);
    expect(collab(tool: "spawn_agent", receivers: []), isNull);
  });

  test("keeps encrypted input opaque and accepts complete plaintext NEW_TASK", () {
    final marker = _line(
      type: "inter_agent_communication_metadata",
      payload: const {"trigger_turn": true},
    );
    final encrypted = repository.subAgentRolloutFact(
      line: _agentMessage(
        content: const [
          {"type": "input_text", "text": "envelope only"},
          {"type": "encrypted_content", "encrypted_content": "opaque"},
        ],
      ),
      previousLine: marker,
    );
    expect(
      encrypted,
      isA<CodexSubAgentInitialInputFact>().having((fact) => fact.input, "input", isA<CodexSubAgentEncryptedInput>()),
    );

    final plaintext = repository.subAgentRolloutFact(
      line: _agentMessage(
        content: const [
          {
            "type": "input_text",
            "text": "Message Type: NEW_TASK\nTask name: /root/worker\nSender: /root\nPayload:\nchild task",
          },
        ],
      ),
      previousLine: marker,
    );
    if (plaintext is! CodexSubAgentInitialInputFact) fail("expected an initial input fact, got $plaintext");
    final plaintextFact = plaintext;
    expect(plaintextFact.turnId, "child-turn-1");
    expect(
      (plaintextFact.input as CodexSubAgentPlaintextInput).message,
      "child task",
    );
  });

  test("rejects input without adjacent marker or valid native envelope", () {
    final message = _agentMessage(
      content: const [
        {"type": "input_text", "text": "child task"},
      ],
    );
    expect(
      repository.subAgentRolloutFact(line: message, previousLine: null),
      isNull,
    );
    expect(
      repository.subAgentRolloutFact(
        line: message,
        previousLine: _line(
          type: "inter_agent_communication_metadata",
          payload: const {"trigger_turn": true},
        ),
      ),
      isNull,
    );
  });
}

CodexRolloutLineDto _agentMessage({
  required List<Map<String, Object>> content,
}) => _line(
  type: "response_item",
  payload: {
    "type": "agent_message",
    "id": "message-1",
    "author": "/root",
    "recipient": "/root/worker",
    "content": content,
    "internal_chat_message_metadata_passthrough": const {
      "turn_id": "child-turn-1",
    },
  },
);

CodexRolloutLineDto _line({
  required String type,
  required Map<String, Object> payload,
}) => CodexRolloutLineDto.fromJson({"type": type, "payload": payload});
