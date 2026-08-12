import "../host/host_process_service.dart";
import "plugin_config.dart";
import "start_abort_signal.dart";

/// Optional descriptor capability for an interactive backend login flow.
abstract interface class InteractivePluginAuthenticationDescriptor {
  /// Starts one plugin-owned authentication operation.
  ///
  /// The first actionable event is a challenge. The plugin must release every
  /// process and subscription it owns before the stream completes or errors.
  /// Aborting settles with `PluginStartAbortedException` after cleanup.
  Stream<PluginAuthenticationEvent> authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal aborted,
  });
}

sealed class PluginAuthenticationEvent {
  const PluginAuthenticationEvent();
}

final class PluginAuthenticationDeviceCodeChallenge extends PluginAuthenticationEvent {
  const PluginAuthenticationDeviceCodeChallenge({
    required this.verificationUri,
    required this.userCode,
  });

  final Uri verificationUri;
  final String userCode;
}

final class PluginAuthenticationCompleted extends PluginAuthenticationEvent {
  const PluginAuthenticationCompleted();
}

final class PluginAuthenticationFailed extends PluginAuthenticationEvent {
  const PluginAuthenticationFailed({required this.message});

  final String message;
}
