import "../../models/claude_permission_mode.dart";
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
/// Every variant keeps the raw frame so later mappers can reach fields this
/// build does not model, and so an unrecognized frame is never lost.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 2.
sealed class const ClaudeStreamMessage({
  /// The session this frame belongs to. Present on every observed frame, but
  /// nullable because the transport must not drop a frame that omits it.
  required final String? sessionId,

  /// The CLI's own id for this frame.
  required final String? uuid,

  /// The undecoded frame.
  required final Map<String, Object?> raw,
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
      return ClaudeUnknownMessage(type: null, subtype: null, sessionId: sessionId, uuid: uuid, raw: json);
    }
    final subtype = _stringOrNull(json["subtype"]);

    switch (type) {
      case "system":
        return switch (subtype) {
          "init" => ClaudeInitMessage.fromJson(json, sessionId: sessionId, uuid: uuid),
          "api_retry" => ClaudeApiRetryMessage.fromJson(json, sessionId: sessionId, uuid: uuid),
          "status" => ClaudeStatusMessage(
            status: _stringOrNull(json["status"]),
            sessionId: sessionId,
            uuid: uuid,
            raw: json,
          ),
          "thinking_tokens" => ClaudeThinkingTokensMessage(
            estimatedTokens: _intOrNull(json["estimated_tokens"]),
            estimatedTokensDelta: _intOrNull(json["estimated_tokens_delta"]),
            sessionId: sessionId,
            uuid: uuid,
            raw: json,
          ),
          "task_progress" => ClaudeTaskProgressMessage.fromJson(json, sessionId: sessionId, uuid: uuid),
          "task_started" => ClaudeTaskStartedMessage(
            taskId: _stringOrNull(json["task_id"]),
            toolUseId: _stringOrNull(json["tool_use_id"]),
            description: _stringOrNull(json["description"]),
            taskType: ClaudeTaskType.parse(json["task_type"]),
            sessionId: sessionId,
            uuid: uuid,
            raw: json,
          ),
          "task_notification" => ClaudeTaskNotificationMessage(
            taskId: _stringOrNull(json["task_id"]),
            toolUseId: _stringOrNull(json["tool_use_id"]),
            status: ClaudeTaskStatus.parse(json["status"]),
            summary: _stringOrNull(json["summary"]),
            sessionId: sessionId,
            uuid: uuid,
            raw: json,
          ),
          "hook_started" => ClaudeHookStartedMessage(
            hookId: _stringOrNull(json["hook_id"]),
            hookName: _stringOrNull(json["hook_name"]),
            hookEvent: _stringOrNull(json["hook_event"]),
            sessionId: sessionId,
            uuid: uuid,
            raw: json,
          ),
          // `hook_progress` shares the output shape and the same emitter, so it
          // is modelled here rather than left to surface as a later unknown.
          "hook_progress" || "hook_response" => ClaudeHookOutputMessage.fromJson(
            json,
            phase: subtype == "hook_progress" ? ClaudeHookPhase.progress : ClaudeHookPhase.response,
            sessionId: sessionId,
            uuid: uuid,
          ),
          _ => ClaudeUnknownMessage(type: type, subtype: subtype, sessionId: sessionId, uuid: uuid, raw: json),
        };
      case "tool_progress":
        return ClaudeToolProgressMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "assistant":
        return ClaudeAssistantMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "user":
        return ClaudeUserMessage(
          message: _mapOrEmpty(json["message"]),
          parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
          toolUseResult: ClaudeToolUseResult.parse(json["tool_use_result"]),
          timestamp: _dateTimeOrNull(json["timestamp"]),
          sessionId: sessionId,
          uuid: uuid,
          raw: json,
        );
      case "stream_event":
        return ClaudeStreamEventMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "result":
        return ClaudeResultMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "control_request":
        return ClaudeControlRequestMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "control_response":
        return ClaudeControlResponseMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "rate_limit_event":
        return ClaudeRateLimitMessage(
          info: _mapOrEmpty(json["rate_limit_info"]),
          sessionId: sessionId,
          uuid: uuid,
          raw: json,
        );
      default:
        return ClaudeUnknownMessage(type: type, subtype: subtype, sessionId: sessionId, uuid: uuid, raw: json);
    }
  }
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

double? _doubleOrNull(Object? value) => value is num ? value.toDouble() : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;

DateTime? _dateTimeOrNull(Object? value) => value is String ? DateTime.tryParse(value) : null;

Map<String, Object?> _mapOrEmpty(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<String> _stringList(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is String) entry,
      ]
    : const <String>[];

/// `system`/`init` — the per-process handshake frame.
final class const ClaudeInitMessage({
  /// The selected model token, which carries a context-window suffix that the
  /// per-message model does not — prefer the message's own model when stamping.
  required final String? model,
  required final ClaudePermissionMode? permissionMode,

  /// Feature flags to detect against rather than sniffing versions, e.g.
  /// `interrupt_cancel_queued_v1`.
  required final List<String> capabilities,
  required final List<String> tools,
  required final List<String> slashCommands,
  required final String? cliVersion,
  required final String? cwd,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    return ClaudeInitMessage(
      model: _stringOrNull(json["model"]),
      permissionMode: ClaudePermissionMode.tryParse(_stringOrNull(json["permissionMode"])),
      capabilities: _stringList(json["capabilities"]),
      tools: _stringList(json["tools"]),
      slashCommands: _stringList(json["slash_commands"]),
      cliVersion: _stringOrNull(json["claude_code_version"]),
      cwd: _stringOrNull(json["cwd"]),
      sessionId: sessionId,
      uuid: uuid,
      raw: json,
    );
  }

  bool supports(String capability) => capabilities.contains(capability);
}

/// `system`/`status` — a coarse work-state signal such as `requesting`.
final class const ClaudeStatusMessage({
  required final String? status,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage;

/// `system`/`thinking_tokens` — a running estimate of the current thinking
/// block's token count, emitted alongside thinking deltas.
final class const ClaudeThinkingTokensMessage({
  required final int? estimatedTokens,
  required final int? estimatedTokensDelta,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage;

/// `system`/`task_progress` — periodic progress for a running subagent task.
final class const ClaudeTaskProgressMessage({
  required final String? taskId,
  required final String? toolUseId,
  required final String? description,
  required final String? subagentType,
  required final String? lastToolName,
  required final String? summary,
  required final int? totalTokens,
  required final int? toolUses,
  required final int? durationMs,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final usage = _mapOrEmpty(json["usage"]);
    return ClaudeTaskProgressMessage(
      taskId: _stringOrNull(json["task_id"]),
      toolUseId: _stringOrNull(json["tool_use_id"]),
      description: _stringOrNull(json["description"]),
      subagentType: _stringOrNull(json["subagent_type"]),
      lastToolName: _stringOrNull(json["last_tool_name"]),
      summary: _stringOrNull(json["summary"]),
      totalTokens: _intOrNull(usage["total_tokens"]),
      toolUses: _intOrNull(usage["tool_uses"]),
      durationMs: _intOrNull(usage["duration_ms"]),
      sessionId: sessionId,
      uuid: uuid,
      raw: json,
    );
  }
}

/// `system`/`task_started` — a background task (sub-agent, shell, workflow)
/// began inside the resident process. For an `Agent` call [taskId] is the
/// sub-agent id, which is also its transcript stem `agent-<taskId>`.
final class const ClaudeTaskStartedMessage({
  required final String? taskId,
  required final String? toolUseId,
  required final String? description,
  required final ClaudeTaskType taskType,
  required super.sessionId,
  required super.uuid,
  required super.raw,
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
  required super.raw,
}) extends ClaudeStreamMessage;

/// `tool_progress` — periodic elapsed-time progress for a running tool call.
final class const ClaudeToolProgressMessage({
  required final String? toolUseId,
  required final String? toolName,
  required final String? parentToolUseId,
  required final double? elapsedTimeSeconds,
  required final String? taskId,
  required final bool? heartbeat,
  required final String? subagentType,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) => ClaudeToolProgressMessage(
    toolUseId: _stringOrNull(json["tool_use_id"]),
    toolName: _stringOrNull(json["tool_name"]),
    parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
    elapsedTimeSeconds: _doubleOrNull(json["elapsed_time_seconds"]),
    taskId: _stringOrNull(json["task_id"]),
    heartbeat: _boolOrNull(json["heartbeat"]),
    subagentType: _stringOrNull(json["subagent_type"]),
    sessionId: sessionId,
    uuid: uuid,
    raw: json,
  );
}

/// `system`/`hook_started` — a hook began running for a lifecycle event.
final class const ClaudeHookStartedMessage({
  required final String? hookId,
  required final String? hookName,

  /// The lifecycle event that triggered the hook, e.g. `PreToolUse`.
  required final String? hookEvent,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage;

enum ClaudeHookPhase() {
  progress,
  response,
}

/// `system`/`hook_progress` and `system`/`hook_response` — streamed and final
/// output from a running hook. `exitCode` only arrives with the final frame.
final class const ClaudeHookOutputMessage({
  required final ClaudeHookPhase phase,
  required final String? hookId,
  required final String? hookName,
  required final String? hookEvent,
  required final String? stdout,
  required final String? stderr,
  required final int? exitCode,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required ClaudeHookPhase phase,
    required String? sessionId,
    required String? uuid,
  }) => ClaudeHookOutputMessage(
    phase: phase,
    hookId: _stringOrNull(json["hook_id"]),
    hookName: _stringOrNull(json["hook_name"]),
    hookEvent: _stringOrNull(json["hook_event"]),
    stdout: _stringOrNull(json["stdout"]),
    stderr: _stringOrNull(json["stderr"]),
    exitCode: _intOrNull(json["exit_code"]),
    sessionId: sessionId,
    uuid: uuid,
    raw: json,
  );
}

enum ClaudeAssistantError() {
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
  required final int? maxRetries,
  required final int? retryDelayMs,
  required final int? errorStatus,
  required final ClaudeAssistantError error,

  /// The CLI-provided retry error, retained verbatim for user-facing status.
  required final String? rawError,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) => ClaudeApiRetryMessage(
    attempt: _intOrNull(json["attempt"]),
    maxRetries: _intOrNull(json["max_retries"]),
    retryDelayMs: _intOrNull(json["retry_delay_ms"]),
    errorStatus: _intOrNull(json["error_status"]),
    error: ClaudeAssistantError.parse(json["error"]),
    rawError: _stringOrNull(json["error"]),
    sessionId: sessionId,
    uuid: uuid,
    raw: json,
  );
}

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
  required final DateTime? timestamp,
  required super.sessionId,
  required super.uuid,
  required super.raw,
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
      timestamp: _dateTimeOrNull(json["timestamp"]),
      sessionId: sessionId,
      uuid: uuid,
      raw: json,
    );
  }
}

/// A user frame. Also carries `tool_result` blocks that complete tool calls.
final class const ClaudeUserMessage({
  required final Map<String, Object?> message,
  required final String? parentToolUseId,

  /// The frame-level typed result of the tool call this frame completes.
  required final ClaudeToolUseResult toolUseResult,
  required final DateTime? timestamp,
  required super.sessionId,
  required super.uuid,
  required super.raw,
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
  required super.raw,
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
      raw: json,
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
  required final String? stopReason,
  required final ClaudeTerminalReason terminalReason,

  /// Tools refused during the turn.
  ///
  /// Rejections answered through `can_use_tool` are correlated by `tool_use_id`
  /// before presentation. An unmatched entry on an otherwise successful turn
  /// indicates that the host was not asked, so it remains a diagnostic error.
  required final List<Map<String, Object?>> permissionDenials,
  required final List<String> errors,
  required final int? apiErrorStatus,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final denials = json["permission_denials"];
    return ClaudeResultMessage(
      subtype: ClaudeResultSubtype.parse(json["subtype"]),
      isError: json["is_error"] == true,
      result: _stringOrNull(json["result"]),
      stopReason: _stringOrNull(json["stop_reason"]),
      terminalReason: ClaudeTerminalReason.parse(json["terminal_reason"]),
      permissionDenials: denials is List
          ? [
              for (final entry in denials)
                if (entry is Map) entry.cast<String, Object?>(),
            ]
          : const <Map<String, Object?>>[],
      errors: _stringList(json["errors"]),
      apiErrorStatus: _intOrNull(json["api_error_status"]),
      sessionId: sessionId,
      uuid: uuid,
      raw: json,
    );
  }
}

/// A CLI-originated control request, notably `can_use_tool`.
final class const ClaudeControlRequestMessage({
  /// Echo this when responding.
  required final String? requestId,
  required final String? subtype,
  required final Map<String, Object?> request,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  factory fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) {
    final request = _mapOrEmpty(json["request"]);
    return ClaudeControlRequestMessage(
      requestId: _stringOrNull(json["request_id"]),
      subtype: _stringOrNull(request["subtype"]),
      request: request,
      sessionId: sessionId,
      uuid: uuid,
      raw: json,
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
  required super.raw,
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
      raw: json,
    );
  }
}

/// Rate-limit state pushed alongside a turn.
final class const ClaudeRateLimitMessage({
  required final Map<String, Object?> info,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage {
  String? get status => _stringOrNull(info["status"]);
}

/// Any frame this build does not model.
///
/// Absorbed deliberately: `rate_limit_event` and `system`/`status` were both
/// absent from the protocol research and present in the first live capture.
final class const ClaudeUnknownMessage({
  required final String? type,
  required final String? subtype,
  required super.sessionId,
  required super.uuid,
  required super.raw,
}) extends ClaudeStreamMessage;
