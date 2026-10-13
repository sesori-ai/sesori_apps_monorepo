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

enum PluginMcpConnectionPhase() { unknown, pending, connecting, connected, authenticationRequired, disabled }

sealed class const PluginMcpConnectionState();

final class const PluginMcpConnectionStatus({required final PluginMcpConnectionPhase phase})
    extends PluginMcpConnectionState;

final class const PluginMcpConnectionFailed({required final String message}) extends PluginMcpConnectionState;

enum PluginMcpAuthorizationState() { unknown, notRequired, required, authenticated }

enum PluginMcpConfigurationScope() { harness, project, session }

enum PluginMcpConfigurationMutability() { unknown, userManaged, readOnly }

/// Presentation metadata, never the native configuration itself.
final class const PluginMcpConfigurationSource({
  required final PluginMcpConfigurationScope scope,
  required final PluginMcpConfigurationMutability mutability,
});

final class const PluginMcpTool({required final String name, required final String? description});

sealed class const PluginMcpToolInventory();

final class const PluginMcpToolsAvailable({required final List<PluginMcpTool> tools}) extends PluginMcpToolInventory;

final class const PluginMcpToolsUnavailable() extends PluginMcpToolInventory;

final class const PluginMcpToolsFailed({required final String message}) extends PluginMcpToolInventory;

enum PluginMcpConnectorOfferAvailability() { unknown, available, setupRequired, unavailable }

sealed class const PluginMcpInventoryEntry();

final class const PluginMcpServerSnapshot({
  required final PluginMcpServerTarget target,
  required final String name,
  required final String? description,
  required final String? endpointOrigin,
  required final PluginMcpConnectionState connection,
  required final PluginMcpAuthorizationState authorization,
  required final PluginMcpConfigurationSource? configuration,
  required final PluginMcpToolInventory tools,
}) extends PluginMcpInventoryEntry;

final class const PluginMcpConnectorOfferSnapshot({
  required final PluginMcpConnectorOfferTarget target,
  required final String name,
  required final String? description,
  required final PluginMcpConnectorOfferAvailability availability,
}) extends PluginMcpInventoryEntry;

sealed class const PluginMcpCatalogAvailability();

final class const PluginMcpCatalogAvailable() extends PluginMcpCatalogAvailability;

final class const PluginMcpCatalogNotSupported() extends PluginMcpCatalogAvailability;

final class const PluginMcpCatalogUnavailable({required final String message}) extends PluginMcpCatalogAvailability;

enum PluginMcpInventoryUnavailableReason() { unsupportedScope, liveSessionRequired }

sealed class const PluginMcpInventoryResult();

final class const PluginMcpInventorySnapshot({
  required final List<PluginMcpInventoryEntry> entries,
  required final PluginMcpCatalogAvailability connectors,
}) extends PluginMcpInventoryResult;

final class const PluginMcpInventoryUnavailable({
  required final PluginMcpInventoryUnavailableReason reason,
  required final String message,
}) extends PluginMcpInventoryResult;
