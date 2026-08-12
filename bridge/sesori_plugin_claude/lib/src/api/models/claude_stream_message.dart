import "../../models/claude_permission_mode.dart";

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
sealed class ClaudeStreamMessage {
  const ClaudeStreamMessage({required this.sessionId, required this.uuid, required this.raw});

  /// The session this frame belongs to. Present on every observed frame, but
  /// nullable because the transport must not drop a frame that omits it.
  final String? sessionId;

  /// The CLI's own id for this frame.
  final String? uuid;

  /// The undecoded frame.
  final Map<String, Object?> raw;

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
          _ => ClaudeUnknownMessage(type: type, subtype: subtype, sessionId: sessionId, uuid: uuid, raw: json),
        };
      case "assistant":
        return ClaudeAssistantMessage.fromJson(json, sessionId: sessionId, uuid: uuid);
      case "user":
        return ClaudeUserMessage(
          message: _mapOrEmpty(json["message"]),
          parentToolUseId: _stringOrNull(json["parent_tool_use_id"]),
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
final class ClaudeInitMessage extends ClaudeStreamMessage {
  const ClaudeInitMessage({
    required this.model,
    required this.permissionMode,
    required this.capabilities,
    required this.tools,
    required this.slashCommands,
    required this.cliVersion,
    required this.cwd,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeInitMessage.fromJson(
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

  /// The selected model token, which carries a context-window suffix that the
  /// per-message model does not — prefer the message's own model when stamping.
  final String? model;

  final ClaudePermissionMode? permissionMode;

  /// Feature flags to detect against rather than sniffing versions, e.g.
  /// `interrupt_cancel_queued_v1`.
  final List<String> capabilities;

  final List<String> tools;
  final List<String> slashCommands;
  final String? cliVersion;
  final String? cwd;

  bool supports(String capability) => capabilities.contains(capability);
}

/// `system`/`status` — a coarse work-state signal such as `requesting`.
final class ClaudeStatusMessage extends ClaudeStreamMessage {
  const ClaudeStatusMessage({
    required this.status,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  final String? status;
}

enum ClaudeAssistantError {
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
final class ClaudeApiRetryMessage extends ClaudeStreamMessage {
  const ClaudeApiRetryMessage({
    required this.attempt,
    required this.maxRetries,
    required this.retryDelayMs,
    required this.errorStatus,
    required this.error,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeApiRetryMessage.fromJson(
    Map<String, Object?> json, {
    required String? sessionId,
    required String? uuid,
  }) => ClaudeApiRetryMessage(
    attempt: _intOrNull(json["attempt"]),
    maxRetries: _intOrNull(json["max_retries"]),
    retryDelayMs: _intOrNull(json["retry_delay_ms"]),
    errorStatus: _intOrNull(json["error_status"]),
    error: ClaudeAssistantError.parse(json["error"]),
    sessionId: sessionId,
    uuid: uuid,
    raw: json,
  );

  final int? attempt;
  final int? maxRetries;
  final int? retryDelayMs;
  final int? errorStatus;
  final ClaudeAssistantError error;
}

/// A complete assistant message.
///
/// Ordering trap: this frame arrives *before* the turn's `content_block_stop`,
/// `message_delta`, and `message_stop` stream events, not after them.
final class ClaudeAssistantMessage extends ClaudeStreamMessage {
  const ClaudeAssistantMessage({
    required this.message,
    required this.messageId,
    required this.model,
    required this.parentToolUseId,
    required this.error,
    required this.timestamp,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeAssistantMessage.fromJson(
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

  /// The raw Anthropic message. Content blocks are typed in the content mapper,
  /// not here, so the transport stays independent of block shapes.
  final Map<String, Object?> message;

  final String? messageId;

  /// The resolved model for this message. This, not the init model, is what
  /// assistant envelopes are stamped with.
  final String? model;

  /// Non-null marks subagent traffic.
  final String? parentToolUseId;
  final ClaudeAssistantError error;
  final DateTime? timestamp;
}

/// A user frame. Also carries `tool_result` blocks that complete tool calls.
final class ClaudeUserMessage extends ClaudeStreamMessage {
  const ClaudeUserMessage({
    required this.message,
    required this.parentToolUseId,
    required this.timestamp,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  final Map<String, Object?> message;
  final String? parentToolUseId;
  final DateTime? timestamp;
}

enum ClaudeStreamEventType {
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

enum ClaudeStreamDeltaType {
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

enum ClaudeResultSubtype {
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

enum ClaudeTerminalReason {
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
final class ClaudeStreamEventMessage extends ClaudeStreamMessage {
  const ClaudeStreamEventMessage({
    required this.event,
    required this.eventType,
    required this.parentToolUseId,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeStreamEventMessage.fromJson(
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

  final Map<String, Object?> event;

  /// `message_start`, `content_block_start`, `content_block_delta`,
  /// `content_block_stop`, `message_delta`, or `message_stop`.
  final ClaudeStreamEventType eventType;

  int? get blockIndex => _intOrNull(event["index"]);
  Map<String, Object?> get contentBlock => _mapOrEmpty(event["content_block"]);
  Map<String, Object?> get delta => _mapOrEmpty(event["delta"]);
  ClaudeStreamDeltaType get deltaType => ClaudeStreamDeltaType.parse(delta["type"]);

  final String? parentToolUseId;
}

/// The end of a turn.
final class ClaudeResultMessage extends ClaudeStreamMessage {
  const ClaudeResultMessage({
    required this.subtype,
    required this.isError,
    required this.result,
    required this.stopReason,
    required this.terminalReason,
    required this.permissionDenials,
    required this.errors,
    required this.apiErrorStatus,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeResultMessage.fromJson(
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

  final ClaudeResultSubtype subtype;
  final bool isError;
  final String? result;
  final String? stopReason;
  final ClaudeTerminalReason terminalReason;

  /// Tools refused during the turn.
  ///
  /// Rejections answered through `can_use_tool` are correlated by `tool_use_id`
  /// before presentation. An unmatched entry on an otherwise successful turn
  /// indicates that the host was not asked, so it remains a diagnostic error.
  final List<Map<String, Object?>> permissionDenials;
  final List<String> errors;
  final int? apiErrorStatus;
}

/// A CLI-originated control request, notably `can_use_tool`.
final class ClaudeControlRequestMessage extends ClaudeStreamMessage {
  const ClaudeControlRequestMessage({
    required this.requestId,
    required this.subtype,
    required this.request,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeControlRequestMessage.fromJson(
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

  /// Echo this when responding.
  final String? requestId;

  final String? subtype;
  final Map<String, Object?> request;
}

/// A reply to a control request we sent.
final class ClaudeControlResponseMessage extends ClaudeStreamMessage {
  const ClaudeControlResponseMessage({
    required this.requestId,
    required this.isSuccess,
    required this.payload,
    required this.error,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  factory ClaudeControlResponseMessage.fromJson(
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

  final String? requestId;
  final bool isSuccess;
  final Map<String, Object?> payload;
  final String? error;
}

/// Rate-limit state pushed alongside a turn.
final class ClaudeRateLimitMessage extends ClaudeStreamMessage {
  const ClaudeRateLimitMessage({
    required this.info,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  final Map<String, Object?> info;

  String? get status => _stringOrNull(info["status"]);
}

/// Any frame this build does not model.
///
/// Absorbed deliberately: `rate_limit_event` and `system`/`status` were both
/// absent from the protocol research and present in the first live capture.
final class ClaudeUnknownMessage extends ClaudeStreamMessage {
  const ClaudeUnknownMessage({
    required this.type,
    required this.subtype,
    required super.sessionId,
    required super.uuid,
    required super.raw,
  });

  final String? type;
  final String? subtype;
}
