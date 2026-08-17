import "package:claude_plugin/claude_plugin.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeStreamMessage.parse", () {
    test("reads the init handshake frame", () {
      final message = ClaudeStreamMessage.parse(sampleInit());

      expect(message, isA<ClaudeInitMessage>());
      final init = message as ClaudeInitMessage;
      expect(init.sessionId, testSessionId);
      expect(init.model, "test-model-large[1m]");
      expect(init.permissionMode, ClaudePermissionMode.auto);
      expect(init.tools, ["Read", "Write"]);
      expect(init.slashCommands, ["review"]);
      expect(init.cliVersion, "2.1.221");
      expect(init.cwd, "/tmp/project");
    });

    test("exposes init capabilities for feature detection", () {
      final init = ClaudeStreamMessage.parse(sampleInit()) as ClaudeInitMessage;

      // Capability detection is how the plugin decides what a given CLI build
      // supports, instead of comparing version strings.
      expect(init.supports("interrupt_cancel_queued_v1"), isTrue);
      expect(init.supports("some_future_capability"), isFalse);
    });

    test("prefers the message model over the init model on an assistant frame", () {
      // The init model carries a context-window selection suffix that the
      // resolved per-message model does not; envelopes stamp the latter.
      final message =
          ClaudeStreamMessage.parse({
                "type": "assistant",
                "session_id": "session-1",
                "message": {"id": "msg_1", "model": "test-model-large", "content": <Object?>[]},
              })
              as ClaudeAssistantMessage;

      expect(message.model, "test-model-large");
      expect(message.messageId, "msg_1");
      expect(message.parentToolUseId, isNull);
    });

    test("marks subagent traffic by parent tool use id", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "assistant",
                "message": {"id": "msg_2", "content": <Object?>[]},
                "parent_tool_use_id": "toolu_parent",
              })
              as ClaudeAssistantMessage;

      expect(message.parentToolUseId, "toolu_parent");
    });

    test("reads a stream event and its inner type", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "stream_event",
                "event": {
                  "type": "content_block_delta",
                  "index": 0,
                  "delta": {"type": "text_delta", "text": "po"},
                },
              })
              as ClaudeStreamEventMessage;

      expect(message.eventType, ClaudeStreamEventType.contentBlockDelta);
      expect(message.deltaType, ClaudeStreamDeltaType.text);
      expect(message.event["index"], 0);
    });

    test("reads a result frame including its permission denials", () {
      // A non-empty denial list on an otherwise successful turn is the
      // signature of a missing --permission-prompt-tool stdio, so it must
      // survive parsing rather than being dropped.
      final message =
          ClaudeStreamMessage.parse({
                "type": "result",
                "subtype": "success",
                "is_error": false,
                "result": "done",
                "stop_reason": "end_turn",
                "terminal_reason": "completed",
                "permission_denials": [
                  {"tool_name": "Write", "tool_use_id": "toolu_1"},
                ],
              })
              as ClaudeResultMessage;

      expect(message.subtype, ClaudeResultSubtype.success);
      expect(message.isError, isFalse);
      expect(message.stopReason, "end_turn");
      expect(message.terminalReason, ClaudeTerminalReason.completed);
      expect(message.permissionDenials, hasLength(1));
      expect(message.permissionDenials.single["tool_name"], "Write");
    });

    test("reads an API retry frame without retaining raw error text", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "system",
                "subtype": "api_retry",
                "session_id": "session-1",
                "attempt": 2,
                "max_retries": 4,
                "retry_delay_ms": 1500,
                "error_status": 429,
                "error": "rate_limit",
              })
              as ClaudeApiRetryMessage;

      expect(message.attempt, 2);
      expect(message.maxRetries, 4);
      expect(message.retryDelayMs, 1500);
      expect(message.errorStatus, 429);
      expect(message.error, ClaudeAssistantError.rateLimit);
    });

    test("reads both declared and success-shaped error results", () {
      final budget =
          ClaudeStreamMessage.parse({
                "type": "result",
                "subtype": "error_max_budget_usd",
                "is_error": true,
                "terminal_reason": "budget_exhausted",
                "errors": ["raw backend detail"],
              })
              as ClaudeResultMessage;
      final apiError =
          ClaudeStreamMessage.parse({
                "type": "result",
                "subtype": "success",
                "is_error": true,
                "terminal_reason": "api_error",
                "api_error_status": 404,
              })
              as ClaudeResultMessage;

      expect(budget.subtype, ClaudeResultSubtype.errorMaxBudgetUsd);
      expect(budget.terminalReason, ClaudeTerminalReason.budgetExhausted);
      expect(budget.errors, ["raw backend detail"]);
      expect(apiError.subtype, ClaudeResultSubtype.success);
      expect(apiError.isError, isTrue);
      expect(apiError.apiErrorStatus, 404);
    });

    test("reads a can_use_tool control request", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "control_request",
                "request_id": "req-uuid",
                "request": {
                  "subtype": "can_use_tool",
                  "tool_name": "Write",
                  "tool_use_id": "toolu_1",
                  "input": {"file_path": "/tmp/x"},
                },
              })
              as ClaudeControlRequestMessage;

      expect(message.requestId, "req-uuid");
      expect(message.subtype, "can_use_tool");
      expect(message.request["tool_name"], "Write");
    });

    test("treats any non-success control response subtype as a failure", () {
      final failure =
          ClaudeStreamMessage.parse({
                "type": "control_response",
                "response": {"subtype": "error", "request_id": "sesori-1", "error": "nope"},
              })
              as ClaudeControlResponseMessage;
      expect(failure.isSuccess, isFalse);
      expect(failure.error, "nope");

      // A subtype this build does not know must not be mistaken for success.
      final unknown =
          ClaudeStreamMessage.parse({
                "type": "control_response",
                "response": {"subtype": "deferred", "request_id": "sesori-2"},
              })
              as ClaudeControlResponseMessage;
      expect(unknown.isSuccess, isFalse);
    });

    test("reads the rate limit frame the research missed", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "rate_limit_event",
                "rate_limit_info": {"status": "allowed", "rateLimitType": "five_hour"},
              })
              as ClaudeRateLimitMessage;

      expect(message.status, "allowed");
    });

    test("reads thinking token estimates", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "system",
                "subtype": "thinking_tokens",
                "estimated_tokens": 512,
                "estimated_tokens_delta": 64,
              })
              as ClaudeThinkingTokensMessage;

      expect(message.estimatedTokens, 512);
      expect(message.estimatedTokensDelta, 64);
    });

    test("reads subagent task progress including nested usage", () {
      final message =
          ClaudeStreamMessage.parse({
                "type": "system",
                "subtype": "task_progress",
                "task_id": "task-1",
                "tool_use_id": "toolu_1",
                "description": "Explore repo",
                "subagent_type": "Explore",
                "last_tool_name": "Grep",
                "summary": "searching",
                "usage": {"total_tokens": 1200, "tool_uses": 3, "duration_ms": 4500},
              })
              as ClaudeTaskProgressMessage;

      expect(message.taskId, "task-1");
      expect(message.toolUseId, "toolu_1");
      expect(message.description, "Explore repo");
      expect(message.subagentType, "Explore");
      expect(message.lastToolName, "Grep");
      expect(message.summary, "searching");
      expect(message.totalTokens, 1200);
      expect(message.toolUses, 3);
      expect(message.durationMs, 4500);
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
      final result =
          ClaudeStreamMessage.parse({
                "type": "result",
                "session_id": 1,
                "uuid": false,
                "subtype": <Object?>[],
                "is_error": "false",
                "result": 2,
                "stop_reason": true,
              })
              as ClaudeResultMessage;

      expect(result.sessionId, isNull);
      expect(result.uuid, isNull);
      expect(result.subtype, ClaudeResultSubtype.unknown);
      expect(result.isError, isFalse);
      expect(result.result, isNull);
      expect(result.stopReason, isNull);
      expect(result.terminalReason, ClaudeTerminalReason.unknown);
    });

    test("tolerates malformed nested payloads without throwing", () {
      // Every nested read is defensive: a wrong-typed member must degrade to an
      // empty map rather than take down the frame.
      final assistant =
          ClaudeStreamMessage.parse({"type": "assistant", "message": "not-a-map"}) as ClaudeAssistantMessage;
      expect(assistant.message, isEmpty);
      expect(assistant.messageId, isNull);

      final result =
          ClaudeStreamMessage.parse({"type": "result", "permission_denials": "not-a-list"}) as ClaudeResultMessage;
      expect(result.permissionDenials, isEmpty);

      final init =
          ClaudeStreamMessage.parse({
                "type": "system",
                "subtype": "init",
                "capabilities": "not-a-list",
                "tools": [1, "Read"],
              })
              as ClaudeInitMessage;
      expect(init.capabilities, isEmpty);
      expect(init.tools, ["Read"]);
    });

    test("keeps the raw frame on every variant", () {
      final json = {"type": "result", "subtype": "success", "custom_field": 42};
      expect(ClaudeStreamMessage.parse(json).raw["custom_field"], 42);
    });
  });
}
