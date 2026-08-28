import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_session_status.freezed.dart";

part "plugin_session_status.g.dart";

/// Backend-neutral session status.
///
/// Its JSON shape intentionally matches shared `SessionStatus`, including the
/// `type` discriminator consumed at the plugin-to-client SSE boundary.
@Freezed(unionKey: "type")
sealed class PluginSessionStatus with _$PluginSessionStatus {
  const factory idle() = PluginSessionStatusIdle;
  const factory busy() = PluginSessionStatusBusy;
  const factory retry({
    required int attempt,
    required String message,
    required int next,
  }) = PluginSessionStatusRetry;
}
