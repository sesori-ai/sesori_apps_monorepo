import "../../models/pi_assistant_stop_reason.dart";
import "pi_frame_fields.dart";

/// One `message_update.assistantMessageEvent` from Pi v0.84.1.
///
/// Pi strips the cumulative `partial` snapshot from these events before writing
/// them to stdout, so a delta carries only its own increment. The full tool
/// call is guaranteed at [PiToolCallEndDelta]; `message_end` stays the final
/// authority for the whole message.
///
/// Wire scalars are nullable throughout: stdout is foreign input, and a frame
/// that omits or mistypes one field must not take down the surrounding turn.
sealed class PiAssistantDelta {
  const PiAssistantDelta({required this.raw});

  /// The undecoded delta, so later mappers can reach fields this build does not
  /// model.
  final Map<String, Object?> raw;

  /// Routes one delta. Unrecognized shapes become [PiUnknownDelta] rather than
  /// being dropped, because a new upstream delta type must not break a turn.
  static PiAssistantDelta parse({required Map<String, Object?> json}) {
    final index = intOrNull(json["contentIndex"]);
    return switch (stringOrNull(json["type"])) {
      "start" => PiMessageStartDelta(raw: json),
      "text_start" => PiTextStartDelta(contentIndex: index, raw: json),
      "text_delta" => PiTextDelta(contentIndex: index, delta: stringOrNull(json["delta"]), raw: json),
      "text_end" => PiTextEndDelta(contentIndex: index, content: stringOrNull(json["content"]), raw: json),
      "thinking_start" => PiThinkingStartDelta(contentIndex: index, raw: json),
      "thinking_delta" => PiThinkingDelta(contentIndex: index, delta: stringOrNull(json["delta"]), raw: json),
      "thinking_end" => PiThinkingEndDelta(contentIndex: index, content: stringOrNull(json["content"]), raw: json),
      "toolcall_start" => PiToolCallStartDelta(contentIndex: index, raw: json),
      "toolcall_delta" => PiToolCallDelta(contentIndex: index, delta: stringOrNull(json["delta"]), raw: json),
      "toolcall_end" => PiToolCallEndDelta(
        contentIndex: index,
        toolCall: mapOrEmpty(json["toolCall"]),
        raw: json,
      ),
      "done" => PiAssistantDoneDelta(
        reason: PiAssistantStopReason.tryParse(value: stringOrNull(json["reason"])),
        message: mapOrEmpty(json["message"]),
        raw: json,
      ),
      "error" => PiAssistantErrorDelta(
        reason: PiAssistantStopReason.tryParse(value: stringOrNull(json["reason"])),
        error: mapOrEmpty(json["error"]),
        raw: json,
      ),
      _ => PiUnknownDelta(type: stringOrNull(json["type"]), raw: json),
    };
  }
}

/// The stream opened. Carries nothing once `partial` is stripped.
final class PiMessageStartDelta extends PiAssistantDelta {
  const PiMessageStartDelta({required super.raw});
}

/// A content block at [contentIndex] started, streamed, or finished.
sealed class PiIndexedDelta extends PiAssistantDelta {
  const PiIndexedDelta({required this.contentIndex, required super.raw});

  final int? contentIndex;
}

final class PiTextStartDelta extends PiIndexedDelta {
  const PiTextStartDelta({required super.contentIndex, required super.raw});
}

final class PiTextDelta extends PiIndexedDelta {
  const PiTextDelta({required super.contentIndex, required this.delta, required super.raw});

  final String? delta;
}

final class PiTextEndDelta extends PiIndexedDelta {
  const PiTextEndDelta({required super.contentIndex, required this.content, required super.raw});

  final String? content;
}

final class PiThinkingStartDelta extends PiIndexedDelta {
  const PiThinkingStartDelta({required super.contentIndex, required super.raw});
}

final class PiThinkingDelta extends PiIndexedDelta {
  const PiThinkingDelta({required super.contentIndex, required this.delta, required super.raw});

  final String? delta;
}

final class PiThinkingEndDelta extends PiIndexedDelta {
  const PiThinkingEndDelta({required super.contentIndex, required this.content, required super.raw});

  final String? content;
}

final class PiToolCallStartDelta extends PiIndexedDelta {
  const PiToolCallStartDelta({required super.contentIndex, required super.raw});
}

/// A fragment of tool-call arguments. The complete call is only guaranteed at
/// [PiToolCallEndDelta].
final class PiToolCallDelta extends PiIndexedDelta {
  const PiToolCallDelta({required super.contentIndex, required this.delta, required super.raw});

  final String? delta;
}

final class PiToolCallEndDelta extends PiIndexedDelta {
  const PiToolCallEndDelta({required super.contentIndex, required this.toolCall, required super.raw});

  /// The complete tool call: id, name, and arguments.
  final Map<String, Object?> toolCall;
}

/// The assistant message finished successfully.
final class PiAssistantDoneDelta extends PiAssistantDelta {
  const PiAssistantDoneDelta({required this.reason, required this.message, required super.raw});

  final PiAssistantStopReason? reason;

  final Map<String, Object?> message;
}

/// The assistant message ended in an error or an abort.
final class PiAssistantErrorDelta extends PiAssistantDelta {
  const PiAssistantErrorDelta({required this.reason, required this.error, required super.raw});

  final PiAssistantStopReason? reason;

  /// The final assistant message carrying the failure.
  final Map<String, Object?> error;
}

/// A delta type this build does not model.
final class PiUnknownDelta extends PiAssistantDelta {
  const PiUnknownDelta({required this.type, required super.raw});

  final String? type;
}
