import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Rebinds native targets to the bridge scope selected by the caller.
class const McpMapper() {
  McpInventoryResult map({required McpScope scope, required PluginMcpInventoryResult result}) => switch (result) {
    PluginMcpInventoryUnavailable(:final reason, :final message) => McpInventoryUnavailable(
      scope: scope,
      reason: switch (reason) {
        PluginMcpInventoryUnavailableReason.unsupportedScope => McpInventoryUnavailableReason.unsupportedScope,
        PluginMcpInventoryUnavailableReason.liveSessionRequired => McpInventoryUnavailableReason.liveSessionRequired,
      },
      message: message,
    ),
    PluginMcpInventorySnapshot(:final entries, :final connectors) => McpInventorySnapshot(
      scope: scope,
      entries: [for (final entry in entries) _entry(scope: scope, entry: entry)],
      connectors: switch (connectors) {
        PluginMcpCatalogAvailable() => const McpCatalogAvailable(),
        PluginMcpCatalogNotSupported() => const McpCatalogNotSupported(),
        PluginMcpCatalogUnavailable(:final message) => McpCatalogUnavailable(message: message),
      },
    ),
  };

  McpInventoryEntry _entry({required McpScope scope, required PluginMcpInventoryEntry entry}) => switch (entry) {
    PluginMcpServerSnapshot() => McpServerSnapshot(
      serverTarget: McpServerTarget(scope: scope, serverKey: entry.target.serverKey),
      name: entry.name,
      description: entry.description,
      endpointOrigin: entry.endpointOrigin,
      connection: switch (entry.connection) {
        PluginMcpConnectionFailed(:final message) => McpConnectionFailed(message: message),
        PluginMcpConnectionStatus(:final phase) => McpConnectionStatus(phase: _connectionPhase(phase: phase)),
      },
      authorization: _authorization(state: entry.authorization),
      configuration: switch (entry.configuration) {
        null => null,
        final source => McpConfigurationSource(
          scope: _configurationScope(scope: source.scope),
          mutability: _configurationMutability(mutability: source.mutability),
        ),
      },
      tools: switch (entry.tools) {
        PluginMcpToolsAvailable(:final tools) => McpToolsAvailable(
          tools: [for (final tool in tools) McpTool(name: tool.name, description: tool.description)],
        ),
        PluginMcpToolsUnavailable() => const McpToolsUnavailable(),
        PluginMcpToolsFailed(:final message) => McpToolsFailed(message: message),
      },
    ),
    PluginMcpConnectorOfferSnapshot() => McpConnectorOfferSnapshot(
      offerTarget: McpConnectorOfferTarget(scope: scope, offerKey: entry.target.offerKey),
      name: entry.name,
      description: entry.description,
      availability: _offerAvailability(availability: entry.availability),
    ),
  };

  McpConnectionPhase _connectionPhase({required PluginMcpConnectionPhase phase}) => switch (phase) {
    PluginMcpConnectionPhase.unknown => McpConnectionPhase.unknown,
    PluginMcpConnectionPhase.pending => McpConnectionPhase.pending,
    PluginMcpConnectionPhase.connecting => McpConnectionPhase.connecting,
    PluginMcpConnectionPhase.connected => McpConnectionPhase.connected,
    PluginMcpConnectionPhase.authenticationRequired => McpConnectionPhase.authenticationRequired,
    PluginMcpConnectionPhase.disabled => McpConnectionPhase.disabled,
  };

  McpAuthorizationState _authorization({required PluginMcpAuthorizationState state}) => switch (state) {
    PluginMcpAuthorizationState.unknown => McpAuthorizationState.unknown,
    PluginMcpAuthorizationState.notRequired => McpAuthorizationState.notRequired,
    PluginMcpAuthorizationState.required => McpAuthorizationState.required,
    PluginMcpAuthorizationState.authenticated => McpAuthorizationState.authenticated,
  };

  McpConfigurationScope _configurationScope({required PluginMcpConfigurationScope scope}) => switch (scope) {
    PluginMcpConfigurationScope.harness => McpConfigurationScope.harness,
    PluginMcpConfigurationScope.project => McpConfigurationScope.project,
    PluginMcpConfigurationScope.session => McpConfigurationScope.session,
  };

  McpConfigurationMutability _configurationMutability({required PluginMcpConfigurationMutability mutability}) =>
      switch (mutability) {
        PluginMcpConfigurationMutability.unknown => McpConfigurationMutability.unknown,
        PluginMcpConfigurationMutability.userManaged => McpConfigurationMutability.userManaged,
        PluginMcpConfigurationMutability.readOnly => McpConfigurationMutability.readOnly,
      };

  McpConnectorOfferAvailability _offerAvailability({required PluginMcpConnectorOfferAvailability availability}) =>
      switch (availability) {
        PluginMcpConnectorOfferAvailability.unknown => McpConnectorOfferAvailability.unknown,
        PluginMcpConnectorOfferAvailability.available => McpConnectorOfferAvailability.available,
        PluginMcpConnectorOfferAvailability.setupRequired => McpConnectorOfferAvailability.setupRequired,
        PluginMcpConnectorOfferAvailability.unavailable => McpConnectorOfferAvailability.unavailable,
      };
}
