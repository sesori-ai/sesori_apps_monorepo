import "package:claude_plugin/claude_plugin.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeStreamMessage.parse", () {
    test("reads the init handshake frame's session id", () {
      final message = ClaudeStreamMessage.parse(sampleInit());

      expect(message, isA<ClaudeInitMessage>().having((init) => init.sessionId, "sessionId", testSessionId));
    });

    test("prefers the message model over the init model on an assistant frame", () {
      // The init model carries a context-window selection suffix that the
      // resolved per-message model does not; envelopes stamp the latter.
      final message = ClaudeStreamMessage.parse({
        "type": "assistant",
        "session_id": "session-1",
        "message": {"id": "msg_1", "model": "test-model-large", "content": <Object?>[]},
      }) as ClaudeAssistantMessage;

      expect(message.model, "test-model-large");
      expect(message.messageId, "msg_1");
      expect(message.parentToolUseId, isNull);
      expect(message.error, ClaudeAssistantError.none);
    });

    test("reads assistant API error metadata", () {
      final message = ClaudeStreamMessage.parse({
        "type": "assistant",
        "session_id": "session-1",
        "error": "rate_limit",
        "api_error_status": 429,
        "message": {
          "id": "synthetic-error",
          "model": "<synthetic>",
          "content": [
            {"type": "text", "text": "rate limited"},
          ],
        },
      }) as ClaudeAssistantMessage;

      expect(message.error, ClaudeAssistantError.rateLimit);
      expect(message.apiErrorStatus, 429);
    });

    test("parses the Claude Code 2.1.322 assistant error codes", () {
      expect(ClaudeAssistantError.parse("account_on_hold"), ClaudeAssistantError.accountOnHold);
      expect(ClaudeAssistantError.parse("verification_required"), ClaudeAssistantError.verificationRequired);
      expect(ClaudeAssistantError.parse("cloud_credential_error"), ClaudeAssistantError.cloudCredentialError);
    });

    test("marks subagent traffic by parent tool use id", () {
      final message = ClaudeStreamMessage.parse({
        "type": "assistant",
        "message": {"id": "msg_2", "content": <Object?>[]},
        "parent_tool_use_id": "toolu_parent",
      }) as ClaudeAssistantMessage;

      expect(message.parentToolUseId, "toolu_parent");
    });

    test("reads a stream event and its inner type", () {
      final message = ClaudeStreamMessage.parse({
        "type": "stream_event",
        "event": {
          "type": "content_block_delta",
          "index": 0,
          "delta": {"type": "text_delta", "text": "po"},
        },
      }) as ClaudeStreamEventMessage;

      expect(message.eventType, ClaudeStreamEventType.contentBlockDelta);
      expect(message.deltaType, ClaudeStreamDeltaType.text);
      expect(message.event["index"], 0);
    });

    test("reads a result frame", () {
      final message = ClaudeStreamMessage.parse({
        "type": "result",
        "subtype": "success",
        "is_error": false,
        "result": "done",
        "terminal_reason": "completed",
      }) as ClaudeResultMessage;

      expect(message.subtype, ClaudeResultSubtype.success);
      expect(message.isError, isFalse);
      expect(message.terminalReason, ClaudeTerminalReason.completed);
    });

    test("reads an API retry frame while retaining raw error text", () {
      final message = ClaudeStreamMessage.parse({
        "type": "system",
        "subtype": "api_retry",
        "session_id": "session-1",
        "attempt": 2,
        "max_retries": 4,
        "retry_delay_ms": 1500,
        "error_status": 429,
        "error": "rate_limit",
      }) as ClaudeApiRetryMessage;

      expect(message.attempt, 2);
      expect(message.retryDelayMs, 1500);
      expect(message.rawError, "rate_limit");
    });

    test("reads both declared and success-shaped error results", () {
      final budget = ClaudeStreamMessage.parse({
        "type": "result",
        "subtype": "error_max_budget_usd",
        "is_error": true,
        "terminal_reason": "budget_exhausted",
        "errors": ["raw backend detail"],
      }) as ClaudeResultMessage;
      final apiError = ClaudeStreamMessage.parse({
        "type": "result",
        "subtype": "success",
        "is_error": true,
        "terminal_reason": "api_error",
        "api_error_status": 404,
      }) as ClaudeResultMessage;

      expect(budget.subtype, ClaudeResultSubtype.errorMaxBudgetUsd);
      expect(budget.terminalReason, ClaudeTerminalReason.budgetExhausted);
      expect(budget.errors, ["raw backend detail"]);
      expect(apiError.subtype, ClaudeResultSubtype.success);
      expect(apiError.isError, isTrue);
      expect(apiError.apiErrorStatus, 404);
    });

    test("reads a can_use_tool control request", () {
      final message = ClaudeStreamMessage.parse({
        "type": "control_request",
        "request_id": "req-uuid",
        "request": {
          "subtype": "can_use_tool",
          "tool_name": "Write",
          "tool_use_id": "toolu_1",
          "input": {"file_path": "/tmp/x"},
        },
      }) as ClaudeControlRequestMessage;

      expect(message.requestId, "req-uuid");
      expect(message.subtype, ClaudeControlRequestSubtype.canUseTool);
      expect(message.request["tool_name"], "Write");
    });

    test("treats any non-success control response subtype as a failure", () {
      final failure = ClaudeStreamMessage.parse({
        "type": "control_response",
        "response": {"subtype": "error", "request_id": "sesori-1", "error": "nope"},
      }) as ClaudeControlResponseMessage;
      expect(failure.isSuccess, isFalse);
      expect(failure.error, "nope");

      // A subtype this build does not know must not be mistaken for success.
      final unknown = ClaudeStreamMessage.parse({
        "type": "control_response",
        "response": {"subtype": "deferred", "request_id": "sesori-2"},
      }) as ClaudeControlResponseMessage;
      expect(unknown.isSuccess, isFalse);
    });

    test("absorbs known frames nothing surfaces without logging them as unknown", () {
      final frames = <Map<String, Object?>>[
        {
          "type": "rate_limit_event",
          "rate_limit_info": <String, Object?>{"status": "allowed"},
        },
        {"type": "system", "subtype": "thinking_tokens", "estimated_tokens": 512},
        {"type": "system", "subtype": "task_progress", "task_id": "task-1"},
        {"type": "tool_progress", "tool_use_id": "toolu_1", "elapsed_time_seconds": 2.5},
        {"type": "system", "subtype": "hook_started", "hook_id": "hook-1"},
        {"type": "system", "subtype": "hook_progress", "hook_id": "hook-1", "stdout": "formatting"},
        {"type": "system", "subtype": "hook_response", "hook_id": "hook-1", "exit_code": 2},
      ];

      for (final frame in frames) {
        expect(ClaudeStreamMessage.parse(frame), isA<ClaudeIgnoredMessage>(), reason: "$frame");
      }
    });

    test("absorbs unknown types and unknown system subtypes", () {
      final unknownType = ClaudeStreamMessage.parse({"type": "some_future_event", "session_id": "s"});
      expect(unknownType, isA<ClaudeUnknownMessage>());
      expect((unknownType as ClaudeUnknownMessage).type, "some_future_event");

      final unknownSubtype = ClaudeStreamMessage.parse({"type": "system", "subtype": "future_subtype"});
      expect(unknownSubtype, isA<ClaudeUnknownMessage>());
      expect((unknownSubtype as ClaudeUnknownMessage).subtype, "future_subtype");
    });

    test("absorbs a frame with a missing or non-string type", () {
      expect(ClaudeStreamMessage.parse({"session_id": "s"}), isA<ClaudeUnknownMessage>());
      expect(ClaudeStreamMessage.parse({"type": 7}), isA<ClaudeUnknownMessage>());
    });

    test("tolerates wrong-typed scalar fields without throwing", () {
      final result = ClaudeStreamMessage.parse({
        "type": "result",
        "session_id": 1,
        "uuid": false,
        "subtype": <Object?>[],
        "is_error": "false",
        "result": 2,
      }) as ClaudeResultMessage;

      expect(result.sessionId, isNull);
      expect(result.uuid, isNull);
      expect(result.subtype, ClaudeResultSubtype.unknown);
      expect(result.isError, isFalse);
      expect(result.result, isNull);
      expect(result.terminalReason, ClaudeTerminalReason.unknown);
    });

    test("tolerates malformed nested payloads without throwing", () {
      // Every nested read is defensive: a wrong-typed member must degrade to an
      // empty map rather than take down the frame.
      final assistant =
          ClaudeStreamMessage.parse({"type": "assistant", "message": "not-a-map"}) as ClaudeAssistantMessage;
      expect(assistant.message, isEmpty);
      expect(assistant.messageId, isNull);
    });

    test("reads the stdin replay mark on a user frame", () {
      final replay = ClaudeStreamMessage.parse({"type": "user", "isReplay": true}) as ClaudeUserMessage;
      final live = ClaudeStreamMessage.parse({"type": "user", "isReplay": "true"}) as ClaudeUserMessage;

      expect(replay.isReplay, isTrue);
      expect(live.isReplay, isFalse);
    });
  });
}
