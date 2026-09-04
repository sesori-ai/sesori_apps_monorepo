import "../host/host_json_store.dart";
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
  PluginAuthenticationOperation authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required HostJsonStore store,
    required StartAbortSignal aborted,
  });
}

/// One plugin-owned login attempt and its backend-neutral continuation kind.
final class const PluginAuthenticationOperation({
  required final Stream<PluginAuthenticationEvent> events,
  required final PluginAuthenticationOperationKind kind,
});

sealed class const PluginAuthenticationOperationKind();

/// Device-code login has no browser redirect for the bridge to submit.
final class const PluginAuthenticationDeviceCodeOperationKind() extends PluginAuthenticationOperationKind;

/// Browser login accepts one redirect URI through the active operation.
final class const PluginAuthenticationBrowserOperationKind({
  required final Future<void> Function({required Uri redirectUri}) submitRedirect,
}) extends PluginAuthenticationOperationKind;

sealed class const PluginAuthenticationEvent();

final class const PluginAuthenticationDeviceCodeChallenge({
  required final Uri verificationUri,
  required final String userCode,
}) extends PluginAuthenticationEvent;

final class const PluginAuthenticationBrowserChallenge({
  required final Uri authorizationUri,
  required final Uri expectedCallbackUri,
}) extends PluginAuthenticationEvent;

final class const PluginAuthenticationCompleted() extends PluginAuthenticationEvent;

final class const PluginAuthenticationFailed({required final String message}) extends PluginAuthenticationEvent;
