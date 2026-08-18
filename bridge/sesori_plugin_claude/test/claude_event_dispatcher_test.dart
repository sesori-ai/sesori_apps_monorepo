import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

void main() {
  group("ClaudeEventDispatcher", () {
    late ClaudeEventDispatcher mapper;

    setUp(() {
      mapper = ClaudeEventDispatcher(content: const ClaudeContentMapper(), tools: ClaudeToolTracker());
    });

    test("creates an assistant when its first visible block starts", () {
      final started = _map(
        mapper,
        _stream(
          "message_start",
          event: {
            "message": {"id": "msg-1", "model": "claude-opus-5"},
          },
        ),
      );
      final textStart = _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {"type": "text", "text": ""},
          },
        ),
      );
      final textDelta = _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 0,
            "delta": {"type": "text_delta", "text": "hello"},
          },
        ),
      );
      final thinkingStart = _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 1,
            "content_block": {"type": "thinking", "thinking": ""},
          },
        ),
      );

      expect(started, isEmpty);
      final info = shared.Message.fromJson((textStart.first as BridgeSseMessageUpdated).info);
      expect(info, isA<shared.MessageAssistant>());
      final assistant = info as shared.MessageAssistant;
      expect(assistant.id, "msg-1");
      expect(assistant.agent, "claude");
      expect(assistant.modelID, "claude-opus-5");
      expect(assistant.providerID, "anthropic");
      expect((textStart.last as BridgeSseMessagePartUpdated).part.type, PluginMessagePartType.text);
      expect((thinkingStart.single as BridgeSseMessagePartUpdated).part.type, PluginMessagePartType.reasoning);
      final delta = textDelta.single as BridgeSseMessagePartDelta;
      expect(delta.partID, "msg-1-block-0");
      expect(delta.field, "text");
      expect(delta.delta, "hello");
    });

    test("does not create an empty assistant for non-visible content", () {
      final started = _map(
        mapper,
        _stream(
          "message_start",
          event: {
            "message": {"id": "msg-hidden", "model": "claude-opus-5"},
          },
        ),
      );
      final block = _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {"type": "redacted_thinking", "data": "opaque"},
          },
        ),
      );
      final complete = _map(
        mapper,
        _assistant(
          id: "msg-hidden",
          content: const [
            {"type": "redacted_thinking", "data": "opaque"},
          ],
        ),
      );

      expect(started, isEmpty);
      expect(block, isEmpty);
      expect(complete, isEmpty);
    });

    test("does not finalize streamed text before Claude closes its block", () {
      _startMessage(mapper, messageId: "msg-stream");
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {"type": "text", "text": ""},
          },
        ),
      );
      _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 0,
            "delta": {"type": "text_delta", "text": "answer"},
          },
        ),
      );

      final complete = _map(
        mapper,
        _assistant(
          id: "msg-stream",
          content: const [
            {"type": "text", "text": "answer"},
          ],
        ),
      );
      final stopped = _map(
        mapper,
        _stream("content_block_stop", event: const {"index": 0}),
      );

      expect(complete.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(stopped.whereType<BridgeSseMessagePartUpdated>().single.part.text, "answer");

      mapper.beginTurn(sessionId: "session-1");
      final replayed = _map(
        mapper,
        _assistant(
          id: "msg-stream",
          content: const [
            {"type": "text", "text": "next answer"},
          ],
        ),
      );
      expect(replayed.whereType<BridgeSseMessagePartUpdated>().single.part.text, "next answer");
    });

    test("hides local command records and keeps the last real model", () {
      _startMessage(mapper, messageId: "msg-real", model: "claude-opus-5");
      _startMessage(mapper, messageId: "msg-command", model: "<synthetic>");
      final assistant = _map(
        mapper,
        _assistant(
          id: "msg-command",
          model: "<synthetic>",
          content: const [
            {"type": "text", "text": "<local-command-stdout>Set model to haiku</local-command-stdout>"},
          ],
        ),
      );
      final user = _map(
        mapper,
        _user(
          uuid: "user-command",
          content: const [
            {"type": "text", "text": "<command-name>/model</command-name>"},
          ],
        ),
      );
      final error = _map(
        mapper,
        {
          "type": "result",
          "subtype": "success",
          "session_id": "session-1",
          "uuid": "result-error",
          "is_error": true,
          "terminal_reason": "api_error",
        },
      ).single as BridgeSseMessageUpdated;

      expect(assistant, isEmpty);
      expect(user, isEmpty);
      expect((shared.Message.fromJson(error.info) as shared.MessageError).modelID, "claude-opus-5");
    });

    test("keeps a prompt that merely mentions internal command markers", () {
      final mentioned = _map(
        mapper,
        _user(
          uuid: "user-mention",
          content: const [
            {"type": "text", "text": "What does <command-name> mean in <local-command-stdout> output?"},
          ],
        ),
      );

      expect((mentioned.first as BridgeSseMessageUpdated).info["id"], "user-mention");
      expect(
        (mentioned.last as BridgeSseMessagePartUpdated).part.text,
        "What does <command-name> mean in <local-command-stdout> output?",
      );
    });

    test("maps tool input and completion with one diff signal", () {
      _startMessage(mapper, messageId: "msg-tool");
      final started = _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {
              "type": "tool_use",
              "id": "toolu-1",
              "name": "Write",
              "input": <String, Object?>{},
            },
          },
        ),
      );
      final input = _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 0,
            "delta": {"type": "input_json_delta", "partial_json": '{"file_path":"a.dart"}'},
          },
        ),
      );
      _map(
        mapper,
        _assistant(
          id: "msg-tool",
          content: [
            {
              "type": "tool_use",
              "id": "toolu-1",
              "name": "Write",
              "input": {"file_path": "a.dart"},
            },
          ],
        ),
      );
      final completed = _map(
        mapper,
        _user(
          uuid: "result-frame",
          content: [
            {"type": "tool_result", "tool_use_id": "toolu-1", "content": "done"},
          ],
        ),
      );
      final duplicate = _map(
        mapper,
        _user(
          uuid: "duplicate-frame",
          content: [
            {"type": "tool_result", "tool_use_id": "toolu-1", "content": "later", "is_error": true},
          ],
        ),
      );

      expect(
        started.whereType<BridgeSseMessagePartUpdated>().single.part.state?.status,
        PluginToolStatus.pending,
      );
      expect((input.single as BridgeSseMessagePartUpdated).part.state?.status, PluginToolStatus.running);
      expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));
      final terminal = completed.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(terminal.state?.status, PluginToolStatus.completed);
      expect(terminal.state?.output, "done");
      expect(duplicate.whereType<BridgeSseSessionDiff>(), isEmpty);
      expect(duplicate.whereType<BridgeSseMessagePartUpdated>().single.part.state, terminal.state);
    });

    test("emits one finalized snapshot when a streamed tool block stops", () {
      _startMessage(mapper, messageId: "msg-tool-stop");
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {
              "type": "tool_use",
              "id": "toolu-stop",
              "name": "Read",
              "input": <String, Object?>{},
            },
          },
        ),
      );
      _map(
        mapper,
        _assistant(
          id: "msg-tool-stop",
          content: const [
            {
              "type": "tool_use",
              "id": "toolu-stop",
              "name": "Read",
              "input": {"file_path": "a.dart"},
            },
          ],
        ),
      );

      final stopped = _map(
        mapper,
        _stream("content_block_stop", event: const {"index": 0}),
      );

      expect(stopped.whereType<BridgeSseMessagePartUpdated>(), hasLength(1));
    });

    test("emits todo staleness only when TodoWrite reaches a terminal result", () {
      _startMessage(mapper, messageId: "msg-todo");
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {
              "type": "tool_use",
              "id": "toolu-todo",
              "name": "TodoWrite",
              "input": <String, Object?>{},
            },
          },
        ),
      );

      final events = _map(
        mapper,
        _user(
          uuid: "result-frame",
          content: [
            {"type": "tool_result", "tool_use_id": "toolu-todo", "content": "updated"},
          ],
        ),
      );

      expect(events.whereType<BridgeSseTodoUpdated>(), hasLength(1));
      expect(events.whereType<BridgeSseSessionDiff>(), isEmpty);
    });

    test("maps visible users by wrapper identity and suppresses tool-result-only users", () {
      final visible = _map(
        mapper,
        _user(
          uuid: "user-frame",
          timestamp: "2026-08-10T10:00:00.000Z",
          content: [
            {"type": "text", "text": "hello"},
          ],
        ),
      );
      final unmatchedResult = _map(
        mapper,
        _user(
          uuid: "result-frame",
          content: [
            {"type": "tool_result", "tool_use_id": "missing", "content": "secret"},
          ],
        ),
      );

      final user = shared.Message.fromJson((visible.first as BridgeSseMessageUpdated).info) as shared.MessageUser;
      expect(user.id, "user-frame");
      expect(user.time?.created, DateTime.utc(2026, 8, 10, 10).millisecondsSinceEpoch);
      expect((visible.last as BridgeSseMessagePartUpdated).part.id, "user-frame-block-0");
      expect(unmatchedResult, isEmpty);
    });

    test("strips the bridge worktree envelope from a replayed user frame", () {
      const envelope =
          "[SYSTEM CONTEXT \u2014 IMPORTANT]\nWorktree path: /private/worktree\n---\n";
      final replayed = _map(
        mapper,
        _user(
          uuid: "replay-frame",
          content: [
            {"type": "text", "text": "${envelope}authored follow-up"},
          ],
        ),
      );
      final contextOnly = _map(
        mapper,
        _user(
          uuid: "context-frame",
          content: [
            {"type": "text", "text": envelope},
          ],
        ),
      );

      expect((replayed.first as BridgeSseMessageUpdated).info["id"], "replay-frame");
      expect((replayed.last as BridgeSseMessagePartUpdated).part.text, "authored follow-up");
      expect(contextOnly, isEmpty);
    });

    test("maps retry and terminal errors with parseable privacy-safe payloads", () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final retry =
          _map(
                mapper,
                {
                  "type": "system",
                  "subtype": "api_retry",
                  "session_id": "session-1",
                  "uuid": "retry-1",
                  "attempt": 2,
                  "max_retries": 4,
                  "retry_delay_ms": 5000,
                  "error_status": 429,
                  "error": "rate_limit",
                },
              ).single
              as BridgeSseSessionStatus;
      final status = shared.SessionStatus.fromJson(retry.status) as shared.SessionStatusRetry;
      expect(status.attempt, 2);
      expect(status.message, "Claude Code is retrying after a rate limit.");
      expect(status.next, inInclusiveRange(before + 5000, DateTime.now().millisecondsSinceEpoch + 5000));

      _startMessage(mapper, messageId: "msg-error", model: "claude-opus-5");
      final error =
          _map(
                mapper,
                {
                  "type": "result",
                  "subtype": "success",
                  "session_id": "session-1",
                  "uuid": "result-error",
                  "is_error": true,
                  "terminal_reason": "api_error",
                  "api_error_status": 404,
                  "result": "raw backend detail must not be forwarded",
                },
              ).single
              as BridgeSseMessageUpdated;
      final info = shared.Message.fromJson(error.info) as shared.MessageError;
      expect(info.errorName, "api_error");
      expect(info.errorMessage, "Claude Code could not complete the API request (HTTP 404).");
      expect(info.errorMessage, isNot(contains("raw backend detail")));
      expect(info.modelID, "claude-opus-5");
      expect(info.providerID, "anthropic");
    });

    test("complete live assistant shapes match transcript history", () {
      const content = <Object?>[
        {"type": "text", "text": "answer"},
        {"type": "thinking", "thinking": "reason", "signature": "opaque"},
        {
          "type": "tool_use",
          "id": "toolu-1",
          "name": "Read",
          "input": {"file_path": "a.dart"},
        },
      ];
      const resultContent = <Object?>[
        {"type": "tool_result", "tool_use_id": "toolu-1", "content": "file body"},
      ];
      final timestamp = DateTime.utc(2026, 8, 10, 10);
      final liveEvents = <BridgeSseEvent>[
        ..._map(
          mapper,
          _assistant(
            id: "msg-1",
            model: "claude-opus-5",
            timestamp: timestamp.toIso8601String(),
            content: content,
          ),
        ),
        ..._map(mapper, _user(uuid: "result-frame", content: resultContent)),
      ];
      final liveInfo = shared.Message.fromJson(
        liveEvents.whereType<BridgeSseMessageUpdated>().last.info,
      );
      final liveParts = <String, PluginMessagePart>{
        for (final event in liveEvents.whereType<BridgeSseMessagePartUpdated>()) event.part.id: event.part,
      };

      final history = const ClaudeHistoryMapper(content: ClaudeContentMapper())
          .map(
            sessionId: "session-1",
            records: [
              ClaudeTranscriptAssistantRecord(
                id: "msg-1",
                model: "claude-opus-5",
                content: content,
                cwd: "/tmp/project",
                timestamp: timestamp,
                isSidechain: false,
                gitBranch: null,
                version: null,
                sessionId: "session-1",
                raw: const {},
              ),
              ClaudeTranscriptUserRecord(
                id: "result-frame",
                content: resultContent,
                isMeta: false,
                isVisibleInTranscriptOnly: false,
                cwd: "/tmp/project",
                timestamp: timestamp,
                isSidechain: false,
                gitBranch: null,
                version: null,
                sessionId: "session-1",
                raw: const {},
              ),
            ],
          )
          .single;

      expect(liveInfo.toJson(), history.info.toJson());
      expect(liveParts.values.toList(), history.parts);
    });

    test("turn cleanup and subagent filtering are exact per session", () {
      _startMessage(mapper, messageId: "parent");
      final subagent = _map(
        mapper,
        _assistant(
          id: "child",
          parentToolUseId: "toolu-parent",
          content: [
            {"type": "text", "text": "child output"},
          ],
        ),
      );
      mapper.beginTurn(sessionId: "session-1");
      final staleDelta = _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 0,
            "delta": {"type": "text_delta", "text": "stale"},
          },
        ),
      );

      expect(subagent, isEmpty);
      expect(staleDelta, isEmpty);
    });
  });
}

List<BridgeSseEvent> _map(ClaudeEventDispatcher mapper, Map<String, Object?> frame) =>
    mapper.map(message: ClaudeStreamMessage.parse(frame));

Map<String, Object?> _stream(String eventType, {required Map<String, Object?> event}) => {
  "type": "stream_event",
  "session_id": "session-1",
  "uuid": "stream-frame",
  "parent_tool_use_id": null,
  "event": {"type": eventType, ...event},
};

Map<String, Object?> _assistant({
  required String id,
  required List<Object?> content,
  String model = "claude-opus-5",
  String? timestamp,
  String? parentToolUseId,
}) => {
  "type": "assistant",
  "session_id": "session-1",
  "uuid": "assistant-frame",
  "timestamp": ?timestamp,
  "parent_tool_use_id": ?parentToolUseId,
  "message": {"id": id, "model": model, "content": content},
};

Map<String, Object?> _user({
  required String uuid,
  required List<Object?> content,
  String? timestamp,
}) => {
  "type": "user",
  "session_id": "session-1",
  "uuid": uuid,
  "timestamp": ?timestamp,
  "message": {"role": "user", "content": content},
};

void _startMessage(ClaudeEventDispatcher mapper, {required String messageId, String model = "claude-opus-5"}) {
  _map(
    mapper,
    _stream(
      "message_start",
      event: {
        "message": {"id": messageId, "model": model},
      },
    ),
  );
}
