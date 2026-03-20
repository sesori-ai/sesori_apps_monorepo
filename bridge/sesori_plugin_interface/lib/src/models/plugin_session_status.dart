import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_session_status.freezed.dart";

part "plugin_session_status.g.dart";

@freezed
sealed class PluginSessionStatus with _$PluginSessionStatus {
  const factory PluginSessionStatus.idle() = PluginSessionStatusIdle;
  const factory PluginSessionStatus.busy() = PluginSessionStatusBusy;
  const factory PluginSessionStatus.retry({
    required int attempt,
    required String message,
    required int next,
  }) = PluginSessionStatusRetry;
}
