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

      mapper.beginTurn(sessionId: "session-1", directory: "/tmp/project");
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

    test("finalizes streamed text when Claude sends the assistant after block stop", () {
      _startMessage(mapper, messageId: "msg-late-assistant");
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
            "delta": {"type": "text_delta", "text": "persisted answer"},
          },
        ),
      );

      final stopped = _map(
        mapper,
        _stream("content_block_stop", event: const {"index": 0}),
      );
      final complete = _map(
        mapper,
        _assistant(
          id: "msg-late-assistant",
          content: const [
            {"type": "text", "text": "persisted answer"},
          ],
        ),
      );

      expect(stopped.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(complete.whereType<BridgeSseMessagePartUpdated>().single.part.text, "persisted answer");
    });

    test("numbers per-block assistant frames across the whole message", () {
      // Claude Code emits one `assistant` frame per content block under the
      // same message id, before that block stops, with the block alone at
      // content offset 0 (verified against CLI 2.1.237).
      _startMessage(mapper, messageId: "msg-split");
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 0,
            "content_block": {"type": "thinking", "thinking": ""},
          },
        ),
      );
      _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 0,
            "delta": {"type": "thinking_delta", "thinking": "reason"},
          },
        ),
      );
      _map(
        mapper,
        _assistant(
          id: "msg-split",
          content: const [
            {"type": "thinking", "thinking": "reason", "signature": "opaque"},
          ],
        ),
      );
      final thinkingStopped = _map(mapper, _stream("content_block_stop", event: const {"index": 0}));
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 1,
            "content_block": {"type": "text", "text": ""},
          },
        ),
      );
      final textDelta = _map(
        mapper,
        _stream(
          "content_block_delta",
          event: {
            "index": 1,
            "delta": {"type": "text_delta", "text": "answer"},
          },
        ),
      );
      final textComplete = _map(
        mapper,
        _assistant(
          id: "msg-split",
          content: const [
            {"type": "text", "text": "answer"},
          ],
        ),
      );
      final textStopped = _map(mapper, _stream("content_block_stop", event: const {"index": 1}));
      _map(
        mapper,
        _stream(
          "content_block_start",
          event: {
            "index": 2,
            "content_block": {
              "type": "tool_use",
              "id": "toolu-split",
              "name": "Read",
              "input": <String, Object?>{},
            },
          },
        ),
      );
      final toolComplete = _map(
        mapper,
        _assistant(
          id: "msg-split",
          content: const [
            {
              "type": "tool_use",
              "id": "toolu-split",
              "name": "Read",
              "input": {"file_path": "a.dart"},
            },
          ],
        ),
      );
      final toolStopped = _map(mapper, _stream("content_block_stop", event: const {"index": 2}));

      final thinking = thinkingStopped.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(thinking.id, "msg-split-block-0");
      expect(thinking.type, PluginMessagePartType.reasoning);
      expect(thinking.text, "reason");
      expect((textDelta.single as BridgeSseMessagePartDelta).partID, "msg-split-block-1");
      // The complete text must finalize the streamed block-1 part, never land
      // on block-0 as a second text copy over the thinking part.
      expect(textComplete.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      final text = textStopped.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(text.id, "msg-split-block-1");
      expect(text.type, PluginMessagePartType.text);
      expect(text.text, "answer");
      expect(toolComplete.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      final tool = toolStopped.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(tool.id, "toolu-split");
      expect(tool.state.status, PluginToolStatus.running);
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
                },
              ).single
              as BridgeSseMessageUpdated;

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
        started.whereType<BridgeSseMessagePartUpdated>().single.part.state.status,
        PluginToolStatus.pending,
      );
      expect((input.single as BridgeSseMessagePartUpdated).part.state.status, PluginToolStatus.running);
      expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));
      final terminal = completed.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(terminal.state.status, PluginToolStatus.completed);
      expect(terminal.state.output, "done");
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
      const envelope = "[SYSTEM CONTEXT \u2014 IMPORTANT]\nWorktree path: /private/worktree\n---\n";
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

    test("renders a synthetic API failure once with the transcript message identity", () {
      _startMessage(mapper, messageId: "msg-real", model: "claude-opus-5");
      final assistantEvents = _map(
        mapper,
        {
          "type": "assistant",
          "session_id": "session-1",
          "uuid": "assistant-error-frame",
          "error": "rate_limit",
          "api_error_status": 429,
          "timestamp": "2026-08-10T10:00:00.000Z",
          "message": {
            "id": "synthetic-error-message",
            "model": "<synthetic>",
            "content": [
              {"type": "text", "text": "You've hit your session limit"},
            ],
          },
        },
      );
      final resultEvents = _map(
        mapper,
        {
          "type": "result",
          "subtype": "success",
          "session_id": "session-1",
          "uuid": "separate-result-identity",
          "is_error": true,
          "terminal_reason": "api_error",
          "api_error_status": 429,
          "result": "You've hit your session limit",
        },
      );

      final info = shared.Message.fromJson((assistantEvents.single as BridgeSseMessageUpdated).info);
      expect(info, isA<shared.MessageError>());
      final error = info as shared.MessageError;
      expect(error.id, "synthetic-error-message");
      expect(error.errorName, "api_error");
      expect(error.errorMessage, "You've hit your session limit");
      expect(error.modelID, "claude-opus-5");
      expect(error.time?.created, DateTime.utc(2026, 8, 10, 10).millisecondsSinceEpoch);
      expect(resultEvents, isEmpty, reason: "the terminal result describes the same API failure");
    });

    test("maps retry and terminal errors without replacing backend text", () {
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
      expect(status.message, "rate_limit");
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
                  "result": "  raw backend detail must be forwarded  ",
                },
              ).single
              as BridgeSseMessageUpdated;
      final info = shared.Message.fromJson(error.info) as shared.MessageError;
      expect(info.errorName, "api_error");
      expect(info.errorMessage, "  raw backend detail must be forwarded  ");
      expect(info.modelID, "claude-opus-5");
      expect(info.providerID, "anthropic");

      final multipleErrors =
          _map(
                mapper,
                {
                  "type": "result",
                  "subtype": "error_during_execution",
                  "session_id": "session-1",
                  "uuid": "result-multiple-errors",
                  "is_error": true,
                  "terminal_reason": "api_error",
                  "errors": ["first backend error", "second backend error"],
                },
              ).single
              as BridgeSseMessageUpdated;
      final multipleInfo = shared.Message.fromJson(multipleErrors.info) as shared.MessageError;
      expect(multipleInfo.errorMessage, "first backend error\nsecond backend error");
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
            agentId: null,
            records: [
              ClaudeTranscriptAssistantRecord(
                id: "msg-1",
                model: "claude-opus-5",
                effort: null,
                content: content,
                cwd: "/tmp/project",
                timestamp: timestamp,
                isSidechain: false,
                agentId: null,
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
                toolUseResult: const ClaudeToolUseResultAbsent(),
                isTaskNotification: false,
                cwd: "/tmp/project",
                timestamp: timestamp,
                isSidechain: false,
                agentId: null,
                gitBranch: null,
                version: null,
                sessionId: "session-1",
                raw: const {},
              ),
            ],
            residentTaskToolUseIds: const {},
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
      mapper.beginTurn(sessionId: "session-1", directory: "/tmp/project");
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
