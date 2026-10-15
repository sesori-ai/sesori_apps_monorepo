/// The native context selected by bridge-owned catalog bindings.
sealed class const PluginMcpScope();

final class const PluginMcpHarnessScope() extends PluginMcpScope;

final class const PluginMcpProjectScope({required final String projectId}) extends PluginMcpScope;

final class const PluginMcpSessionScope({required final String sessionId}) extends PluginMcpScope;

/// Keys are opaque to consumers and owned by the adapter. Server and offer keys
/// remain different targets even when their text is equal.
sealed class const PluginMcpEntryTarget({required final PluginMcpScope scope});

final class const PluginMcpServerTarget({required super.scope, required final String serverKey})
    extends PluginMcpEntryTarget;

final class const PluginMcpConnectorOfferTarget({required super.scope, required final String offerKey})
    extends PluginMcpEntryTarget;

enum PluginMcpConnectionPhase() {
  unknown,
  pending,
  connecting,
  connected,
  authenticationRequired,
  disabled,
}

/// These controls affect the target's native scope, not configuration ownership.
enum PluginMcpServerAction() {
  reconnect,
  enable,
  disable,
}

enum PluginMcpActionEffectScope() {
  harness,
  project,
  session,
}

enum PluginMcpAuthenticationCapabilityUnavailableReason() {
  notSupported,
  notImplemented,
  nativeConfigurationRequired,
}

sealed class const PluginMcpAuthenticationCapability();

final class const PluginMcpAuthenticationCapabilityAvailable({required final PluginMcpActionEffectScope effectScope})
    extends PluginMcpAuthenticationCapability;

final class const PluginMcpAuthenticationCapabilityUnavailable({
  required final PluginMcpAuthenticationCapabilityUnavailableReason reason,
}) extends PluginMcpAuthenticationCapability;

final class const PluginMcpServerActionCapability({
  required final PluginMcpServerAction action,
  required final PluginMcpActionEffectScope effectScope,
});

enum PluginMcpActionUnavailableReason() {
  unsupportedScope,
  liveSessionRequired,
  targetNotFound,
}

sealed class const PluginMcpActionResult();

/// Reports the native action's declared effect, independent of inspection scope.
final class const PluginMcpActionCompleted({required final PluginMcpActionEffectScope effectScope})
    extends PluginMcpActionResult;

final class const PluginMcpActionUnavailable({required final PluginMcpActionUnavailableReason reason})
    extends PluginMcpActionResult;

final class const PluginMcpActionFailed({required final Exception cause, required final StackTrace causeStackTrace})
    extends PluginMcpActionResult;

sealed class const PluginMcpConnectionState();

final class const PluginMcpConnectionStatus({required final PluginMcpConnectionPhase phase})
    extends PluginMcpConnectionState;

final class const PluginMcpConnectionFailed({required final String message}) extends PluginMcpConnectionState;

enum PluginMcpAuthorizationState() {
  unknown,
  notRequired,
  required,
  authenticated,
}

enum PluginMcpConfigurationScope() {
  harness,
  project,
  session,
}

enum PluginMcpConfigurationMutability() {
  unknown,
  userManaged,
  readOnly,
}

/// Presentation metadata, never the native configuration itself.
final class const PluginMcpConfigurationSource({
  required final PluginMcpConfigurationScope scope,
  required final PluginMcpConfigurationMutability mutability,
});

final class const PluginMcpTool({required final String name, required final String? description});

sealed class const PluginMcpToolInventory();

/// Adapters must supply an immutable list (const or List.unmodifiable).
final class const PluginMcpToolsAvailable({required final List<PluginMcpTool> tools}) extends PluginMcpToolInventory;

final class const PluginMcpToolsUnavailable() extends PluginMcpToolInventory;

final class const PluginMcpToolsFailed({required final String message}) extends PluginMcpToolInventory;

enum PluginMcpConnectorOfferAvailability() {
  unknown,
  available,
  setupRequired,
  unavailable,
}

enum PluginMcpConnectorAction() {
  setup,
}

sealed class const PluginMcpInventoryEntry();

final class const PluginMcpServerSnapshot({
  required final PluginMcpServerTarget target,
  required final String name,
  required final String? description,
  required final String? endpointOrigin,
  required final PluginMcpConnectionState connection,
  required final PluginMcpAuthorizationState authorization,
  required final PluginMcpAuthenticationCapability authentication,
  required final PluginMcpAuthenticationCapability credentialForgetting,
  required final PluginMcpConfigurationSource? configuration,
  required final PluginMcpToolInventory tools,
  required final List<PluginMcpServerActionCapability> actions,
}) extends PluginMcpInventoryEntry;

final class const PluginMcpConnectorOfferSnapshot({
  required final PluginMcpConnectorOfferTarget target,
  required final String name,
  required final String? description,
  required final PluginMcpConnectorOfferAvailability availability,
  required final List<PluginMcpConnectorAction> actions,
}) extends PluginMcpInventoryEntry;

sealed class const PluginMcpCatalogAvailability();

final class const PluginMcpCatalogAvailable() extends PluginMcpCatalogAvailability;

final class const PluginMcpCatalogNotSupported() extends PluginMcpCatalogAvailability;

final class const PluginMcpCatalogUnavailable({required final String message}) extends PluginMcpCatalogAvailability;

enum PluginMcpInventoryUnavailableReason() {
  unsupportedScope,
  liveSessionRequired,
}

sealed class const PluginMcpInventoryResult();

/// Adapters must supply immutable entries, including each server tool list.
final class const PluginMcpInventorySnapshot({
  required final List<PluginMcpInventoryEntry> entries,
  required final PluginMcpCatalogAvailability servers,
  required final PluginMcpCatalogAvailability connectors,
}) extends PluginMcpInventoryResult;

final class const PluginMcpInventoryUnavailable({
  required final PluginMcpInventoryUnavailableReason reason,
  required final String message,
}) extends PluginMcpInventoryResult;

/// A failed live read retains local diagnostics without exporting native errors.
final class const PluginMcpInventoryReadFailed({
  required final Exception cause,
  required final StackTrace causeStackTrace,
}) extends PluginMcpInventoryResult;
