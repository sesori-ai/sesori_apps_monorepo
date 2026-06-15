import "package:freezed_annotation/freezed_annotation.dart";

part "message.freezed.dart";

part "message.g.dart";

/// Sealed class representing a message in a session.
///
/// Three variants:
/// - [MessageUser]: a message sent by the user
/// - [MessageAssistant]: a regular assistant response
/// - [MessageError]: an assistant message that failed with an error
///
/// The JSON serialization uses `"role"` as the union key. Each variant
/// serializes with its corresponding role value:
/// - `MessageUser`: `"user"`
/// - `MessageAssistant`: `"assistant"`
/// - `MessageError`: `"error"`
///
/// The bridge layer is responsible for normalizing backend-specific error
/// shapes (e.g., a nested `error.data.message`) into the flat
/// `errorName` and `errorMessage` fields before constructing a
/// [MessageError].
@Freezed(unionKey: "role", fromJson: true, toJson: true)
sealed class Message with _$Message {
  const Message._();

  const factory Message.user({
    required String id,
    required String sessionID,
    required String? agent,
    required MessageTime? time,
  }) = MessageUser;

  const factory Message.assistant({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required MessageTime? time,
  }) = MessageAssistant;

  const factory Message.error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String errorName,
    required String errorMessage,
    required MessageTime? time,
  }) = MessageError;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

/// Lifecycle timestamps for a [Message], in milliseconds since the Unix
/// epoch (matching [SessionTime] and the backend wire format).
///
/// - [created]: when the message was created (user send time / assistant
///   generation start).
/// - [completed]: when the message finished (assistant streaming ended);
///   `null` for user messages and in-flight assistant messages.
@Freezed(fromJson: true, toJson: true)
sealed class MessageTime with _$MessageTime {
  const factory MessageTime({
    required int created,
    required int? completed,
  }) = _MessageTime;

  factory MessageTime.fromJson(Map<String, dynamic> json) => _$MessageTimeFromJson(json);
}
