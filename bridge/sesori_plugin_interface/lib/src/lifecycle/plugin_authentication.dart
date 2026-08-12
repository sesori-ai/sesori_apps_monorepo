import "../host/host_process_service.dart";
import "plugin_config.dart";
import "start_abort_signal.dart";

/// Optional descriptor capability for an interactive backend login flow.
abstract interface class InteractivePluginAuthenticationDescriptor() {
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

sealed class const PluginAuthenticationEvent();

final class const PluginAuthenticationDeviceCodeChallenge({
  required final Uri verificationUri,
  required final String userCode,
}) extends PluginAuthenticationEvent;

final class const PluginAuthenticationCompleted() extends PluginAuthenticationEvent;

final class const PluginAuthenticationFailed({required final String message}) extends PluginAuthenticationEvent;
