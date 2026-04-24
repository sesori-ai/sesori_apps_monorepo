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
/// shapes (e.g., OpenCode's nested `error.data.message`) into the flat
/// `errorName` and `errorMessage` fields before constructing a
/// [MessageError].
@Freezed(unionKey: "role", fromJson: true, toJson: true)
sealed class Message with _$Message {
  const Message._();

  const factory Message.user({
    required String id,
    required String sessionID,
    required String? agent,
  }) = MessageUser;

  const factory Message.assistant({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
  }) = MessageAssistant;

  const factory Message.error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String errorName,
    required String errorMessage,
  }) = MessageError;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  /// The role of this message ("user", "assistant", or "error").
  String get role => switch (this) {
    MessageUser() => "user",
    MessageAssistant() => "assistant",
    MessageError() => "error",
  };
}
