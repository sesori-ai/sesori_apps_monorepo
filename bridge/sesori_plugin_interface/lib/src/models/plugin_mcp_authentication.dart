import "plugin_mcp.dart";

enum PluginMcpAuthenticationUnavailableReason() {
  /// The harness cannot authenticate servers in this requested scope.
  unsupportedScope,

  /// This scope requires an already running agent session; none is resident.
  liveSessionRequired,

  /// The exact server key no longer occurs in native inventory.
  targetNotFound,

  /// Native credential commands cannot safely address this configuration.
  nativeConfigurationRequired,

  /// The verified native API does not support authentication for this target.
  notSupported,

  /// Sesori has not implemented this host/transport's native boundary yet.
  notImplemented,
}

final class const PluginMcpAuthenticationUnavailableException({
  required final PluginMcpAuthenticationUnavailableReason reason,
}) implements Exception {
  @override
  String toString() => "MCP authentication unavailable: ${reason.name}";
}

/// A rejected callback retains its cause without displaying authorization data.
final class const PluginMcpAuthenticationCallbackRejectedException({required final Object innerError})
    implements Exception {
  @override
  String toString() => "The callback does not match this MCP authentication attempt";
}

typedef PluginMcpSubmitCallback = Future<void> Function({required Uri callbackUri});

/// One native attempt. Consumers subscribe once and hold the runtime until done.
sealed class const PluginMcpAuthenticationOperation({required final PluginMcpActionEffectScope effectScope}) {
  Stream<PluginMcpAuthenticationEvent> get events;
  PluginMcpSubmitCallback get submitCallback;
}

/// Cancellation stops the native attempt and releases its resources.
final class const PluginMcpCancelableAuthentication({
  required super.effectScope,
  @override required final Stream<PluginMcpAuthenticationEvent> events,
  @override required final PluginMcpSubmitCallback submitCallback,
  required final Future<void> Function() cancel,
}) extends PluginMcpAuthenticationOperation;

/// The native API has no cancellation method; retain ownership until settlement.
final class const PluginMcpNativeSettlementAuthentication({
  required super.effectScope,
  @override required final Stream<PluginMcpAuthenticationEvent> events,
  @override required final PluginMcpSubmitCallback submitCallback,
}) extends PluginMcpAuthenticationOperation;

sealed class const PluginMcpAuthenticationEvent();

enum PluginMcpAuthenticationFailureReason() {
  nativeFailure,
  declined,
  expired,
  nativeTrustRequired,
}

final class const PluginMcpAuthenticationChallenge({
  required final Uri authorizationUri,
  required final Uri expectedCallbackUri,
}) extends PluginMcpAuthenticationEvent {
  @override
  String toString() => "MCP authentication challenge";
}

final class const PluginMcpAuthenticationCompleted() extends PluginMcpAuthenticationEvent;

final class const PluginMcpAuthenticationFailed({
  required final PluginMcpAuthenticationFailureReason reason,
  required final Exception cause,
  required final StackTrace causeStackTrace,
}) extends PluginMcpAuthenticationEvent;
