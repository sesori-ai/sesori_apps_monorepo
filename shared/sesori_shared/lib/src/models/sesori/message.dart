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
/// The bridge layer is responsible for flattening backend-specific error
/// shapes (e.g., a nested `error.data.message`) into `errorName` and
/// `errorMessage`. Backend-provided text is preserved verbatim; a harness may
/// synthesize a fallback only when its backend supplied no error text.
@Freezed(unionKey: "role", fromJson: true, toJson: true)
sealed class const Message._() with _$Message {
  const factory user({
    required String id,
    required String sessionID,
    required String? agent,
    required MessageTime? time,

    /// The `SendPromptRequest.promptId` this message fulfilled, when known.
    ///
    /// Attached on the live event that consumes a bridge-queued prompt so
    /// clients can swap the queued bubble for this message atomically.
    /// History reads that cannot reconstruct it carry null.
    required String? promptId,
  }) = MessageUser;

  const factory assistant({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required MessageTime? time,
  }) = MessageAssistant;

  const factory error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String errorName,

    /// The backend-provided error text, unchanged when the backend supplied it.
    required String errorMessage,
    required MessageTime? time,
  }) = MessageError;

  factory fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
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
  const factory({
    required int created,
    required int? completed,
  }) = _MessageTime;

  factory fromJson(Map<String, dynamic> json) => _$MessageTimeFromJson(json);
}
