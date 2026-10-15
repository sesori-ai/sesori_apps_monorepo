import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Rebinds native targets to the bridge scope selected by the caller.
class const McpMapper() {
  McpInventoryResult map({required McpScope scope, required PluginMcpInventoryResult result}) => switch (result) {
    PluginMcpInventoryReadFailed() => McpInventoryUnavailable(
      scope: scope,
      reason: McpInventoryUnavailableReason.readFailed,
      message: "MCP inventory could not be read. Refresh to try again.",
    ),
    PluginMcpInventoryUnavailable(:final reason, :final message) => McpInventoryUnavailable(
      scope: scope,
      reason: switch (reason) {
        PluginMcpInventoryUnavailableReason.unsupportedScope => McpInventoryUnavailableReason.unsupportedScope,
        PluginMcpInventoryUnavailableReason.liveSessionRequired => McpInventoryUnavailableReason.liveSessionRequired,
      },
      message: message,
    ),
    PluginMcpInventorySnapshot(:final entries, :final servers, :final connectors) => McpInventorySnapshot(
      scope: scope,
      entries: [for (final entry in entries) _entry(scope: scope, entry: entry)],
      servers: _catalog(availability: servers),
      connectors: _catalog(availability: connectors),
    ),
  };

  McpCatalogAvailability _catalog({required PluginMcpCatalogAvailability availability}) => switch (availability) {
    PluginMcpCatalogAvailable() => const McpCatalogAvailable(),
    PluginMcpCatalogNotSupported() => const McpCatalogNotSupported(),
    PluginMcpCatalogUnavailable(:final message) => McpCatalogUnavailable(message: message),
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
      authentication: _authenticationCapability(capability: entry.authentication),
      credentialForgetting: _authenticationCapability(capability: entry.credentialForgetting),
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
      actions: [
        for (final action in entry.actions)
          McpServerActionCapability(
            action: switch (action.action) {
              PluginMcpServerAction.reconnect => McpServerAction.reconnect,
              PluginMcpServerAction.enable => McpServerAction.enable,
              PluginMcpServerAction.disable => McpServerAction.disable,
            },
            effectScope: switch (action.effectScope) {
              PluginMcpActionEffectScope.harness => McpActionEffectScope.harness,
              PluginMcpActionEffectScope.project => McpActionEffectScope.project,
              PluginMcpActionEffectScope.session => McpActionEffectScope.session,
            },
          ),
      ],
    ),
    PluginMcpConnectorOfferSnapshot() => McpConnectorOfferSnapshot(
      offerTarget: McpConnectorOfferTarget(scope: scope, offerKey: entry.target.offerKey),
      name: entry.name,
      description: entry.description,
      availability: _offerAvailability(availability: entry.availability),
    ),
  };

  McpAuthenticationCapability _authenticationCapability({required PluginMcpAuthenticationCapability capability}) =>
      switch (capability) {
        PluginMcpAuthenticationCapabilityAvailable(:final effectScope) => McpAuthenticationCapabilityAvailable(
          effectScope: switch (effectScope) {
            PluginMcpActionEffectScope.harness => McpActionEffectScope.harness,
            PluginMcpActionEffectScope.project => McpActionEffectScope.project,
            PluginMcpActionEffectScope.session => McpActionEffectScope.session,
          },
        ),
        PluginMcpAuthenticationCapabilityUnavailable(:final reason) => McpAuthenticationCapabilityUnavailable(
          reason: switch (reason) {
            PluginMcpAuthenticationCapabilityUnavailableReason.notSupported =>
              McpAuthenticationCapabilityUnavailableReason.notSupported,
            PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented =>
              McpAuthenticationCapabilityUnavailableReason.notImplemented,
            PluginMcpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired =>
              McpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired,
          },
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
