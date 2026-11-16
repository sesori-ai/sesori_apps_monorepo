import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

const _sessionId = "ses_a";
const _threadId = "01a1e373-e5c1-77b2-8596-7e9ed7678e4c";

/// Line times of the 0.139.0 rollout below, which records a reply only when
/// it finishes.
const _promptOneAt = 1794817385993;
const _replyOneAt = 1794817387366;
const _promptTwoAt = 1794817388102;
const _replyTwoAt = 1794817389758;

void main() {
  test("a live-captured Codex 0.139.0 session keeps one copy of each reply, and its live times, "
      "on its first import", () async {
    final history = createTestChatHistory();
    // What the bridge captured live on 0.139.0: the replies under their
    // app-server item ids, stamped when they started.
    for (final message in [
      _user(id: "live-user-1", text: "Reply with exactly: red.", createdAt: _promptOneAt),
      _reply(id: "msg_red", text: "red", time: const MessageTime(created: 1794817387198, completed: _replyOneAt)),
      _user(id: "live-user-2", text: "Reply with exactly: blue.", createdAt: _promptTwoAt),
      _reply(id: "msg_blue", text: "blue", time: const MessageTime(created: 1794817389623, completed: _replyTwoAt)),
    ]) {
      await history.service.captureMessage(sessionId: _sessionId, message: message.info);
      for (final part in message.parts) {
        await history.service.capturePart(sessionId: _sessionId, part: part);
      }
    }

    await history.repository.replaceSessionMessages(
      sessionId: _sessionId,
      storageScope: testAttachmentStorageScope(sessionId: _sessionId),
      messages: _replay(directory: history.directory),
      lastImportedAt: null,
      watermark: _replyTwoAt,
      backendActivityAt: _replyTwoAt,
      syncedAt: 1794817425616,
      interruptedAfterMessageId: null,
    );

    final stored = (await history.repository.getSessionMessages(
      sessionId: _sessionId,
      storageScope: testAttachmentStorageScope(sessionId: _sessionId),
    )).messages;
    expect(
      [
        for (final message in stored)
          (
            message.info.runtimeType,
            [for (final part in message.parts) (part as MessagePartText).text].join(),
            message.info.time?.created,
          ),
      ],
      [
        (MessageUser, "Reply with exactly: red.", _promptOneAt),
        (MessageAssistant, "red", 1794817387198),
        (MessageUser, "Reply with exactly: blue.", _promptTwoAt),
        (MessageAssistant, "blue", 1794817389623),
      ],
    );
  });

  test("a reply replayed from a 0.139.0 rollout alone carries no time", () {
    final directory = Directory.systemTemp.createTempSync("codex-139-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final replies = [
      for (final message in _replay(directory: directory))
        if (message.info case final MessageAssistant reply) reply,
    ];

    expect(replies.map((reply) => (reply.id, reply.time)), [("m-2", null), ("m-4", null)]);
  });
}

/// The replay of a 0.139.0 rollout shaped like the verification run's: no
/// item ids, and no `item_completed` events.
List<MessageWithParts> _replay({required Directory directory}) {
  final rollout = File(p.join(directory.path, "rollout-2026-11-16T00-23-05-$_threadId.jsonl"))
    ..writeAsStringSync(
      [
        _line(at: _promptOneAt, type: "session_meta", payload: {"id": _threadId, "cwd": "/repo", "cli_version": "0.139.0"}),
        ..._turn(turnId: "turn-1", prompt: "Reply with exactly: red.", promptAt: _promptOneAt, reply: "red", replyAt: _replyOneAt),
        ..._turn(turnId: "turn-2", prompt: "Reply with exactly: blue.", promptAt: _promptTwoAt, reply: "blue", replyAt: _replyTwoAt),
      ].join("\n"),
    );
  final repository = CodexMessageRepository(
    rolloutApi: CodexRolloutApi(environment: const {}),
    rolloutToolMapper: const CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper()),
    userContentMapper: const CodexUserContentMapper(),
  );
  return repository
      .projectMessages(
        read: repository.prepareMessageRead(rolloutPath: rollout.path, sessionId: _threadId),
        sessionId: _sessionId,
        children: const [],
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
        childReplayDataById: const {},
        config: const CodexConfigDefaults(model: "test-model", modelProvider: "test-provider"),
      )
      .toSharedMessageWithParts(sessionId: _sessionId);
}

List<String> _turn({
  required String turnId,
  required String prompt,
  required int promptAt,
  required String reply,
  required int replyAt,
}) => [
  _line(at: promptAt, type: "event_msg", payload: {"type": "task_started", "turn_id": turnId}),
  _line(at: promptAt, type: "turn_context", payload: {"turn_id": turnId, "cwd": "/repo", "model": "test-model"}),
  _line(
    at: promptAt,
    type: "response_item",
    payload: {
      "type": "message",
      "role": "user",
      "content": [
        {"type": "input_text", "text": prompt},
      ],
    },
  ),
  _line(at: promptAt, type: "event_msg", payload: {"type": "user_message", "message": prompt}),
  _line(at: replyAt, type: "event_msg", payload: {"type": "agent_message", "message": reply}),
  _line(
    at: replyAt,
    type: "response_item",
    payload: {
      "type": "message",
      "role": "assistant",
      "content": [
        {"type": "output_text", "text": reply},
      ],
    },
  ),
  _line(at: replyAt, type: "event_msg", payload: {"type": "task_complete", "turn_id": turnId}),
];

String _line({required int at, required String type, required Map<String, Object?> payload}) => jsonEncode({
  "timestamp": DateTime.fromMillisecondsSinceEpoch(at, isUtc: true).toIso8601String(),
  "type": type,
  "payload": payload,
});

MessageWithParts _user({required String id, required String text, required int createdAt}) => MessageWithParts(
  info: Message.user(
    id: id,
    sessionID: _sessionId,
    agent: null,
    time: MessageTime(created: createdAt, completed: null),
    promptId: null,
    invocation: null,
    handoff: null,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: _sessionId, messageID: id, text: text)],
);

MessageWithParts _reply({required String id, required String text, required MessageTime time}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: _sessionId,
    agent: "codex",
    modelID: "test-model",
    providerID: "test-provider",
    time: time,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: _sessionId, messageID: id, text: text)],
);
