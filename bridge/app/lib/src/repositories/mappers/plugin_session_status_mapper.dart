import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginSessionStatusMapper on PluginSessionStatus {
  /// The shared status without a busy time; only `SessionRepository` knows
  /// when the bridge saw a session go busy, and fills it in.
  SessionStatus toSharedSessionStatus() => switch (this) {
    PluginSessionStatusIdle() => const SessionStatus.idle(),
    PluginSessionStatusBusy() => const SessionStatus.busy(since: null),
    PluginSessionStatusRetry(:final attempt, :final message, :final next) => SessionStatus.retry(
      attempt: attempt,
      message: message,
      next: next,
      since: null,
    ),
  };
}
