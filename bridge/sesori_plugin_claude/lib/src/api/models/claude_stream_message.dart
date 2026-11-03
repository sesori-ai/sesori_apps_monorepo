import "../../models/claude_compact_metadata.dart";
import "../../models/claude_message_origin_kind.dart";
import "../../models/claude_task_notification.dart";
import "../../models/claude_task_status.dart";
import "../../models/claude_task_type.dart";
import "../../models/claude_tool_use_result.dart";

/// One line of the CLI's stream-json stdout.
///
/// The wire discriminator is two levels deep — `type`, then `subtype` for
/// `system` frames — so these are hand-written sealed variants with a
/// dispatching parser rather than a generated union. That also matches the
/// transport-envelope precedent in `AcpStdioClient`, which hand-writes its
/// notification and request envelopes; generated DTOs in this package are
/// reserved for content shapes.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 2.
sealed class const ClaudeStreamMessage({
  /// The session this frame belongs to. Present on every observed frame, but
  /// nullable because the transport must not drop a frame that omits it.
  required final String? sessionId,

  /// The CLI's own id for this frame.
  required final String? uuid,
}) {
  /// Parses one decoded stdout line.
  ///
  /// Never throws and never returns null: anything unrecognized becomes
  /// [ClaudeUnknownMessage], because the protocol gains message types
  /// frequently and a strict parser would drop a whole turn over one new frame.
  static ClaudeStreamMessage parse(Map<String, Object?> json) {
    final sessionId = _stringOrNull(json["session_id"]);
    final uuid = _stringOrNull(json["uuid"]);
    final type = json["type"];
    if (type is! String) {
      return ClaudeUnknownMessage(type: null, subtype: null, sessionId: sessionId, uuid: uuid);
    }
    final subtype = _stringOrNull(json["subtype"]);

    switch (type) {
      case "system":
        return switch (subtype) {
          "init" => ClaudeInitMessage(sessionId: sessionId, uuid: uuid),
          "api_retry" => ClaudeApiRetryMessage(
            attempt: _intOrNull(json["attempt"]),
            retryDelayMs: _intOrNull(json["retry_delay_ms"]),
            rawError: _stringOrNull(json["error"]),
            sessionId: sessionId,
            uuid: uuid,
          ),
          "status" => ClaudeStatusMessage(
            isCompacting: json["status"] == "compacting",
            compactResult: ClaudeCompactResult.tryParse(raw: json["compact_result"]),
            compactError: _stringOrNull(json["compact_error"]),
            sessionId: sessionId,
            uuid: uuid,
          ),
          "compact_boundary" => ClaudeCompactBoundaryMessage(
            metadata: ClaudeCompactMetadata.fromJsonOrNull(json: json["compact_metadata"]),
            sessionId: sessionId,
            uuid: uuid,
          ),
          "task_started" => ClaudeTaskStartedMessage(
            taskId: _stringOrNull(json["task_id"]),
            toolUseId: _stringOrNull(json["tool_use_id"]),
            description: _stringOrNull(json["description"]),
            taskType: ClaudeTaskType.parse(json["task_type"]),
            ownedBySubAgent: json["owned_by_subagent"] == true,
            sessionId: sessionId,
            uuid: uuid,
          ),
          "task_notification" => ClaudeTaskNotificationMessage(
            taskId: _stringOrNull(json["task_id"]),
            toolUseId: _stringOrNull(json["tool_use_id"]),
            status: ClaudeTaskStatus.parse(json["status"]),
            summary: _stringOrNull(json["summary"]),
            sessionId: sessionId,
            uuid: uuid,
          ),
          "thinking_tokens" ||
          "task_progress" ||
          "hook_started" ||
          "hook_progress" ||
          "hook_response" => ClaudeIgnoredMessage(sessionId: sessionId, uuid: uuid),
          _ => ClaudeUnknownMessage(type: type, subtype: subtype, sessionId: sessionId, uuid: uuid),
        };
      case "tool_progress" || "rate_limit_event":
        return ClaudeIgnoredMessage(sessionId: sessionId, uuid: uuid);
      case "assistant":
        return ClaudeAssistantMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "user":
        final message = _mapOrEmpty(json["message"]);
        return ClaudeUserMessage(
          message: message,
          parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
          // The stream spells it snake_case; the transcript the CLI replays it
          // from spells it camelCase, and replayed frames have carried both.
          toolUseResult: ClaudeToolUseResult.parse(json["tool_use_result"] ?? json["toolUseResult"]),
          taskNotifications: _taskNotifications(message["content"]),
          originKind: ClaudeMessageOriginKind.parse(kind: _mapOrEmpty(json["origin"])["kind"]),
          isHarnessGenerated: json["isSynthetic"] == true || json["isMeta"] == true,
          isReplay: json["isReplay"] == true,
          timestamp: _dateTimeOrNull(json["timestamp"]),
          sessionId: sessionId,
          uuid: uuid,
        );
      case "stream_event":
        return ClaudeStreamEventMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "result":
        return ClaudeResultMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "control_request":
        return ClaudeControlRequestMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "control_response":
        return ClaudeControlResponseMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      default:
        return ClaudeUnknownMessage(type: type, subtype: subtype, sessionId: sessionId, uuid: uuid);
    }
  }
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

DateTime? _dateTimeOrNull(Object? value) => value is String ? DateTime.tryParse(value) : null;

Map<String, Object?> _mapOrEmpty(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

/// Every `<task-notification>` envelope among a user message's text blocks.
List<ClaudeTaskNotification> _taskNotifications(Object? content) {
  final texts = switch (content) {
    final String text => [text],
    final List<Object?> blocks => [
      for (final block in blocks)
        if (block is Map<Object?, Object?> && block["type"] == "text")
          if (block["text"] case final String text) text,
    ],
    _ => const <String>[],
  };
  return [for (final text in texts) ?ClaudeTaskNotification.tryParse(text)];
}

List<String> _stringList(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is String) entry,
      ]
    : const <String>[];

/// `system`/`init` — the per-process handshake frame. Only its session id is
/// read, to catch a CLI that started a different session than requested.
final class const ClaudeInitMessage({
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// `system`/`compact_boundary` — the CLI compacted the context. The next
/// synthetic `user` frame carries the continuation summary.
final class const ClaudeCompactBoundaryMessage({
  /// Null when the frame carries no `compact_metadata` object.
  required final ClaudeCompactMetadata? metadata,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// `system`/`status` — a coarse work-state signal such as `requesting`.
///
/// A compaction starts with `status: "compacting"`, repeated while it runs,
/// and ends with `status: null` carrying [compactResult] and, on a failure,
/// [compactError]. Verified against Claude CLI 2.1.291.
final class const ClaudeStatusMessage({
  required final bool isCompacting,

  /// Null when the frame does not end a compaction.
  required final ClaudeCompactResult? compactResult,

  /// Why a compaction failed, as the CLI words it.
  required final String? compactError,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// How a compaction ended.
enum ClaudeCompactResult() {
  success,
  failed;

  /// Null when absent or unknown.
  static ClaudeCompactResult? tryParse({required Object? raw}) => switch (raw) {
    "success" => success,
    "failed" => failed,
    _ => null,
  };
}

/// `system`/`task_started` — a background task (sub-agent, shell, workflow)
/// began inside the resident process. For an `Agent` call [taskId] is the
/// sub-agent id, which is also its transcript stem `agent-<taskId>`.
final class const ClaudeTaskStartedMessage({
  required final String? taskId,
  required final String? toolUseId,
  required final String? description,
  required final ClaudeTaskType taskType,

  /// Whether a sub-agent runs the task, such as its own foreground shell
  /// (`owned_by_subagent`, observed on 2.1.301).
  required final bool ownedBySubAgent,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// `system`/`task_notification` — a background task reached a terminal state.
/// Authoritative over the launching call's own tool result.
final class const ClaudeTaskNotificationMessage({
  required final String? taskId,
  required final String? toolUseId,
  required final ClaudeTaskStatus status,
  required final String? summary,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

enum ClaudeAssistantError() {
  none,
  authenticationFailed,
  oauthOrgNotAllowed,
  billingError,
  rateLimit,
  overloaded,
  invalidRequest,
  modelNotFound,
  serverError,
  maxOutputTokens,
  unknown;

  static ClaudeAssistantError parse(Object? raw) => switch (raw) {
    null => none,
    "authentication_failed" => authenticationFailed,
    "oauth_org_not_allowed" => oauthOrgNotAllowed,
    "billing_error" => billingError,
    "rate_limit" => rateLimit,
    "overloaded" => overloaded,
    "invalid_request" => invalidRequest,
    "model_not_found" => modelNotFound,
    "server_error" => serverError,
    "max_output_tokens" => maxOutputTokens,
    _ => unknown,
  };
}

/// `system`/`api_retry` — a retryable API failure with a scheduled retry.
final class const ClaudeApiRetryMessage({
  required final int? attempt,
  required final int? retryDelayMs,

  /// The CLI-provided retry error, retained verbatim for user-facing status.
  required final String? rawError,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// A complete assistant message.
///
/// Ordering trap: this frame arrives *before* the turn's `content_block_stop`,
/// `message_delta`, and `message_stop` stream events, not after them.
final class const ClaudeAssistantMessage({
  /// The raw Anthropic message. Content blocks are typed in the content mapper,
  /// not here, so the transport stays independent of block shapes.
  required final Map<String, Object?> message,
  required final String? messageId,

  /// The resolved model for this message. This, not the init model, is what
  /// assistant envelopes are stamped with.
  required final String? model,

  /// Non-null marks subagent traffic.
  required final String? parentToolUseId,
  required final ClaudeAssistantError error,
  required final int? apiErrorStatus,
  required final DateTime? timestamp,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final message = _mapOrEmpty(json["message"]);
    return ClaudeAssistantMessage(
      message: message,
      messageId: _stringOrNull(message["id"]),
      model: _stringOrNull(message["model"]),
      parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
      error: ClaudeAssistantError.parse(json["error"]),
      apiErrorStatus: _intOrNull(json["api_error_status"] ?? json["apiErrorStatus"]),
      timestamp: _dateTimeOrNull(json["timestamp"]),
      sessionId: sessionId,
      uuid: uuid,
    );
  }
}

/// A user frame. Also carries `tool_result` blocks that complete tool calls.
final class const ClaudeUserMessage({
  required final Map<String, Object?> message,
  required final String? parentToolUseId,

  /// The frame-level typed result of the tool call this frame completes.
  required final ClaudeToolUseResult toolUseResult,

  /// Background-task outcomes this frame delivers to the model as
  /// `<task-notification>` text, parsed here so lifecycle consumers never read
  /// the wire content shape.
  required final List<ClaudeTaskNotification> taskNotifications,

  /// Host-stamped provenance, independent of this frame's `user` role.
  required final ClaudeMessageOriginKind originKind,

  /// The CLI generated this frame rather than the user typing it: the summary
  /// that follows a `compact_boundary`, an injected skill body, an image
  /// caption, or a sub-agent plumbing nudge.
  ///
  /// The stream spells this `isSynthetic` and the transcript the CLI replays
  /// from spells it `isMeta`; both are normalized here so the live dispatcher
  /// and the history mapper decide visibility on one meaning.
  required final bool isHarnessGenerated,

  /// The CLI marked this frame as its echo of a user turn written to stdin.
  /// Attachment echoes can omit the mark.
  required final bool isReplay,
  required final DateTime? timestamp,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

enum ClaudeStreamEventType() {
  messageStart,
  contentBlockStart,
  contentBlockDelta,
  contentBlockStop,
  other;

  static ClaudeStreamEventType parse(Object? raw) => switch (raw) {
    "message_start" => messageStart,
    "content_block_start" => contentBlockStart,
    "content_block_delta" => contentBlockDelta,
    "content_block_stop" => contentBlockStop,
    _ => other,
  };
}

enum ClaudeStreamDeltaType() {
  text,
  thinking,
  inputJson,
  other;

  static ClaudeStreamDeltaType parse(Object? raw) => switch (raw) {
    "text_delta" => text,
    "thinking_delta" => thinking,
    "input_json_delta" => inputJson,
    _ => other,
  };
}

enum ClaudeResultSubtype() {
  success,
  errorDuringExecution,
  errorMaxTurns,
  errorMaxBudgetUsd,
  errorMaxStructuredOutputRetries,
  unknown;

  static ClaudeResultSubtype parse(Object? raw) => switch (raw) {
    "success" => success,
    "error_during_execution" => errorDuringExecution,
    "error_max_turns" => errorMaxTurns,
    "error_max_budget_usd" => errorMaxBudgetUsd,
    "error_max_structured_output_retries" => errorMaxStructuredOutputRetries,
    _ => unknown,
  };
}

enum ClaudeTerminalReason() {
  blockingLimit,
  rapidRefillBreaker,
  promptTooLong,
  imageError,
  modelError,
  apiError,
  malformedToolUseExhausted,
  abortedStreaming,
  abortedTools,
  stopHookPrevented,
  hookStopped,
  toolDeferred,
  maxTurns,
  backgroundRequested,
  completed,
  budgetExhausted,
  structuredOutputRetryExhausted,
  toolDeferredUnavailable,
  turnSetupFailed,
  unknown;

  static ClaudeTerminalReason parse(Object? raw) => switch (raw) {
    "blocking_limit" => blockingLimit,
    "rapid_refill_breaker" => rapidRefillBreaker,
    "prompt_too_long" => promptTooLong,
    "image_error" => imageError,
    "model_error" => modelError,
    "api_error" => apiError,
    "malformed_tool_use_exhausted" => malformedToolUseExhausted,
    "aborted_streaming" => abortedStreaming,
    "aborted_tools" => abortedTools,
    "stop_hook_prevented" => stopHookPrevented,
    "hook_stopped" => hookStopped,
    "tool_deferred" => toolDeferred,
    "max_turns" => maxTurns,
    "background_requested" => backgroundRequested,
    "completed" => completed,
    "budget_exhausted" => budgetExhausted,
    "structured_output_retry_exhausted" => structuredOutputRetryExhausted,
    "tool_deferred_unavailable" => toolDeferredUnavailable,
    "turn_setup_failed" => turnSetupFailed,
    _ => unknown,
  };
}

/// A raw Anthropic streaming event carrying token-level deltas.
final class const ClaudeStreamEventMessage({
  required final Map<String, Object?> event,

  /// `message_start`, `content_block_start`, `content_block_delta`,
  /// `content_block_stop`, `message_delta`, or `message_stop`.
  required final ClaudeStreamEventType eventType,
  required final String? parentToolUseId,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final event = _mapOrEmpty(json["event"]);
    return ClaudeStreamEventMessage(
      event: event,
      eventType: ClaudeStreamEventType.parse(event["type"]),
      parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
      sessionId: sessionId,
      uuid: uuid,
    );
  }

  int? get blockIndex => _intOrNull(event["index"]);
  Map<String, Object?> get contentBlock => _mapOrEmpty(event["content_block"]);
  Map<String, Object?> get delta => _mapOrEmpty(event["delta"]);
  ClaudeStreamDeltaType get deltaType => ClaudeStreamDeltaType.parse(delta["type"]);
}

/// The end of a turn.
final class const ClaudeResultMessage({
  required final ClaudeResultSubtype subtype,
  required final bool isError,
  required final String? result,
  required final ClaudeTerminalReason terminalReason,
  required final List<String> errors,
  required final int? apiErrorStatus,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    return ClaudeResultMessage(
      subtype: ClaudeResultSubtype.parse(json["subtype"]),
      isError: json["is_error"] == true,
      result: _stringOrNull(json["result"]),
      terminalReason: ClaudeTerminalReason.parse(json["terminal_reason"]),
      errors: _stringList(json["errors"]),
      apiErrorStatus: _intOrNull(json["api_error_status"]),
      sessionId: sessionId,
      uuid: uuid,
    );
  }
}

enum ClaudeControlRequestSubtype() {
  canUseTool,
  elicitation,
  unknown;

  static ClaudeControlRequestSubtype parse(Object? raw) => switch (raw) {
    "can_use_tool" => canUseTool,
    "elicitation" => elicitation,
    _ => unknown,
  };
}

/// A CLI-originated control request, notably `can_use_tool`.
final class const ClaudeControlRequestMessage({
  /// Echo this when responding.
  required final String? requestId,
  required final ClaudeControlRequestSubtype subtype,
  required final Map<String, Object?> request,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final request = _mapOrEmpty(json["request"]);
    return ClaudeControlRequestMessage(
      requestId: _stringOrNull(json["request_id"]),
      subtype: ClaudeControlRequestSubtype.parse(request["subtype"]),
      request: request,
      sessionId: sessionId,
      uuid: uuid,
    );
  }
}

/// A reply to a control request we sent.
final class const ClaudeControlResponseMessage({
  required final String? requestId,
  required final bool isSuccess,
  required final Map<String, Object?> payload,
  required final String? error,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final response = _mapOrEmpty(json["response"]);
    final subtype = _stringOrNull(response["subtype"]);
    return ClaudeControlResponseMessage(
      requestId: _stringOrNull(response["request_id"]),
      // Anything that is not an explicit success is treated as a failure, so a
      // subtype this build does not know cannot be mistaken for one.
      isSuccess: subtype == "success",
      payload: _mapOrEmpty(response["response"]),
      error: _stringOrNull(response["error"]),
      sessionId: sessionId,
      uuid: uuid,
    );
  }
}

/// A known frame nothing surfaces: thinking-token estimates, task and tool
/// progress, hook activity, and rate-limit state. Kept apart from
/// [ClaudeUnknownMessage] so these frequent frames are not logged as unknown.
final class const ClaudeIgnoredMessage({
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;

/// Any frame this build does not model.
final class const ClaudeUnknownMessage({
  required final String? type,
  required final String? subtype,
  required super.sessionId,
  required super.uuid,
}) extends ClaudeStreamMessage;
