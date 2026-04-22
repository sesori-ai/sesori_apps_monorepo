import "package:freezed_annotation/freezed_annotation.dart";

part "session_error.freezed.dart";

part "session_error.g.dart";

/// Error payload carried by [SesoriSseEvent.sessionError].
///
/// Mirrors the OpenCode `session.error` event structure:
/// `name` is the error type (e.g. "APIError", "ProviderAuthError"),
/// `message` is the human-readable message.
@Freezed(fromJson: true, toJson: true)
sealed class SessionError with _$SessionError {
  const factory SessionError({
    required String name,
    required String message,
  }) = _SessionError;

  factory SessionError.fromJson(Map<String, dynamic> json) =>
      _$SessionErrorFromJson(json);
}
