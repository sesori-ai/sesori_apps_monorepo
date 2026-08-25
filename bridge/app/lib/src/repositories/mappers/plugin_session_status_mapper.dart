import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginSessionStatusMapper on PluginSessionStatus {
  SessionStatus toSharedSessionStatus() => switch (this) {
    PluginSessionStatusIdle() => const SessionStatus.idle(),
    PluginSessionStatusBusy() => const SessionStatus.busy(),
    PluginSessionStatusRetry(:final attempt, :final message, :final next) => SessionStatus.retry(
      attempt: attempt,
      message: message,
      next: next,
    ),
  };
}
