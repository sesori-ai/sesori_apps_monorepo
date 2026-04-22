import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_session_error.freezed.dart";

part "plugin_session_error.g.dart";

/// Error payload carried by [BridgeSseSessionError].
///
/// Mirrors the OpenCode `session.error` event structure:
/// `name` is the error type (e.g. "APIError", "ProviderAuthError"),
/// `message` is the human-readable message.
@Freezed(fromJson: true, toJson: true)
sealed class PluginSessionError with _$PluginSessionError {
  const factory PluginSessionError({
    required String name,
    required String message,
  }) = _PluginSessionError;

  factory PluginSessionError.fromJson(Map<String, dynamic> json) =>
      _$PluginSessionErrorFromJson(json);
}
