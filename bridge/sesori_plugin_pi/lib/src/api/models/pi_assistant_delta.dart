import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../models/pi_assistant_stop_reason.dart";
import "pi_frame_fields.dart";

/// One `message_update.assistantMessageEvent` from Pi v0.84.4.
///
/// Pi strips cumulative `partial` snapshots from these events before writing
/// them to stdout, so a delta carries only its own increment. Since v0.84.3,
/// `toolcall_start` also carries the tool id and name; the nullable fields keep
/// the supported v0.84.1 floor working when an older binary omits them. The
/// full tool call is guaranteed at [PiToolCallEndDelta]; `message_end` stays
/// the final authority for the whole message.
///
/// Wire scalars are nullable throughout: stdout is foreign input, and a frame
/// that omits or mistypes one field must not take down the surrounding turn.
sealed class const PiAssistantDelta({
  /// The undecoded delta, so later mappers can reach fields this build does not
  /// model.
  required final Map<String, Object?> raw,
}) {
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
      "toolcall_start" => PiToolCallStartDelta(
        contentIndex: index,
        id: stringOrNull(json["id"]),
        toolName: stringOrNull(json["toolName"]),
        raw: json,
      ),
      "toolcall_delta" => PiToolCallDelta(contentIndex: index, delta: stringOrNull(json["delta"]), raw: json),
      "toolcall_end" => PiToolCallEndDelta(
        contentIndex: index,
        toolCall: mapOrEmpty(json["toolCall"]),
        raw: json,
      ),
      "done" => PiAssistantDoneDelta(
        reason: _stopReason(stringOrNull(json["reason"])),
        message: mapOrEmpty(json["message"]),
        raw: json,
      ),
      "error" => PiAssistantErrorDelta(
        reason: _stopReason(stringOrNull(json["reason"])),
        error: mapOrEmpty(json["error"]),
        raw: json,
      ),
      _ => _unknownDelta(json),
    };
  }
}

PiAssistantStopReason? _stopReason(String? value) {
  final reason = PiAssistantStopReason.tryParse(value: value);
  if (value != null && reason == null) Log.w("[pi] received an unknown assistant stop reason");
  return reason;
}

PiAssistantDelta _unknownDelta(Map<String, Object?> json) {
  Log.w("[pi] received an unknown assistant delta type");
  return PiUnknownDelta(type: stringOrNull(json["type"]), raw: json);
}

/// The stream opened. Carries nothing once `partial` is stripped.
final class const PiMessageStartDelta({required super.raw}) extends PiAssistantDelta;

/// A content block at [contentIndex] started, streamed, or finished.
sealed class const PiIndexedDelta({required final int? contentIndex, required super.raw}) extends PiAssistantDelta;

final class const PiTextStartDelta({required super.contentIndex, required super.raw}) extends PiIndexedDelta;

final class const PiTextDelta({required super.contentIndex, required final String? delta, required super.raw})
    extends PiIndexedDelta;

final class const PiTextEndDelta({required super.contentIndex, required final String? content, required super.raw})
    extends PiIndexedDelta;

final class const PiThinkingStartDelta({required super.contentIndex, required super.raw}) extends PiIndexedDelta;

final class const PiThinkingDelta({required super.contentIndex, required final String? delta, required super.raw})
    extends PiIndexedDelta;

final class const PiThinkingEndDelta({required super.contentIndex, required final String? content, required super.raw})
    extends PiIndexedDelta;

final class const PiToolCallStartDelta({
  required super.contentIndex,

  /// Pi v0.84.3+ sends stable metadata here without the cumulative snapshot.
  required final String? id,
  required final String? toolName,
  required super.raw,
}) extends PiIndexedDelta;

/// A fragment of tool-call arguments. The complete call is only guaranteed at
/// [PiToolCallEndDelta].
final class const PiToolCallDelta({required super.contentIndex, required final String? delta, required super.raw})
    extends PiIndexedDelta;

final class const PiToolCallEndDelta({
  required super.contentIndex,

  /// The complete tool call: id, name, and arguments.
  required final Map<String, Object?> toolCall,
  required super.raw,
}) extends PiIndexedDelta;

/// The assistant message finished successfully.
final class const PiAssistantDoneDelta({
  required final PiAssistantStopReason? reason,
  required final Map<String, Object?> message,
  required super.raw,
}) extends PiAssistantDelta;

/// The assistant message ended in an error or an abort.
final class const PiAssistantErrorDelta({
  required final PiAssistantStopReason? reason,

  /// The final assistant message carrying the failure.
  required final Map<String, Object?> error,
  required super.raw,
}) extends PiAssistantDelta;

/// A delta type this build does not model.
final class const PiUnknownDelta({required final String? type, required super.raw}) extends PiAssistantDelta;
