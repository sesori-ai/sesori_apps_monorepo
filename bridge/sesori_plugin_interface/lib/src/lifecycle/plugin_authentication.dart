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

  const factory pastedCode({
    required Stream<PluginAuthenticationPastedCodeEvent> events,
    required Future<void> Function({required String code}) submitCode,
  }) = PluginAuthenticationPastedCodeOperation;

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

/// Pasted-code login accepts one code the user copies from the provider's page
/// after approving access. The bridge calls [submitCode] at most once; it
/// returns once the plugin has the code. A code shape the plugin rejects ends
/// the operation through [events] with [PluginAuthenticationFailed].
final class const PluginAuthenticationPastedCodeOperation({
  @override required final Stream<PluginAuthenticationPastedCodeEvent> events,
  required final Future<void> Function({required String code}) submitCode,
}) extends PluginAuthenticationOperation;

sealed class const PluginAuthenticationEvent();

sealed class const PluginAuthenticationDeviceCodeEvent() implements PluginAuthenticationEvent;

sealed class const PluginAuthenticationBrowserEvent() implements PluginAuthenticationEvent;

sealed class const PluginAuthenticationPastedCodeEvent() implements PluginAuthenticationEvent;

final class const PluginAuthenticationDeviceCodeChallenge({
  required final Uri verificationUri,
  required final String userCode,
}) extends PluginAuthenticationEvent implements PluginAuthenticationDeviceCodeEvent;

final class const PluginAuthenticationBrowserChallenge({
  required final Uri authorizationUri,
  required final Uri expectedCallbackUri,
}) extends PluginAuthenticationEvent implements PluginAuthenticationBrowserEvent;

/// [authorizationUri] is an absolute HTTPS sign-in page the user opens.
final class const PluginAuthenticationPastedCodeChallenge({required final Uri authorizationUri})
    extends PluginAuthenticationEvent
    implements PluginAuthenticationPastedCodeEvent;

final class const PluginAuthenticationCompleted()
    extends PluginAuthenticationEvent
    implements
        PluginAuthenticationDeviceCodeEvent,
        PluginAuthenticationBrowserEvent,
        PluginAuthenticationPastedCodeEvent;

final class const PluginAuthenticationFailed({required final String message})
    extends PluginAuthenticationEvent
    implements
        PluginAuthenticationDeviceCodeEvent,
        PluginAuthenticationBrowserEvent,
        PluginAuthenticationPastedCodeEvent;
