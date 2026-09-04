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

/// One plugin-owned login attempt with challenge events coupled to its continuation behavior.
sealed class const PluginAuthenticationOperation() {
  const factory deviceCode({
    required Stream<PluginAuthenticationDeviceCodeEvent> events,
  }) = PluginAuthenticationDeviceCodeOperation;

  const factory browser({
    required Stream<PluginAuthenticationBrowserEvent> events,
    required Future<void> Function({required Uri redirectUri}) submitRedirect,
  }) = PluginAuthenticationBrowserOperation;

  Stream<PluginAuthenticationEvent> get events;
}

/// Device-code login has no browser redirect for the bridge to submit.
final class const PluginAuthenticationDeviceCodeOperation({
  @override required final Stream<PluginAuthenticationDeviceCodeEvent> events,
}) extends PluginAuthenticationOperation;

/// Browser login accepts one redirect URI through the active operation.
final class const PluginAuthenticationBrowserOperation({
  @override required final Stream<PluginAuthenticationBrowserEvent> events,
  required final Future<void> Function({required Uri redirectUri}) submitRedirect,
}) extends PluginAuthenticationOperation;

sealed class const PluginAuthenticationEvent();

sealed class const PluginAuthenticationDeviceCodeEvent() implements PluginAuthenticationEvent;

sealed class const PluginAuthenticationBrowserEvent() implements PluginAuthenticationEvent;

final class const PluginAuthenticationDeviceCodeChallenge({
  required final Uri verificationUri,
  required final String userCode,
}) extends PluginAuthenticationEvent implements PluginAuthenticationDeviceCodeEvent;

final class const PluginAuthenticationBrowserChallenge({
  required final Uri authorizationUri,
  required final Uri expectedCallbackUri,
}) extends PluginAuthenticationEvent implements PluginAuthenticationBrowserEvent;

final class const PluginAuthenticationCompleted() extends PluginAuthenticationEvent
    implements PluginAuthenticationDeviceCodeEvent, PluginAuthenticationBrowserEvent;

final class const PluginAuthenticationFailed({required final String message}) extends PluginAuthenticationEvent
    implements PluginAuthenticationDeviceCodeEvent, PluginAuthenticationBrowserEvent;
