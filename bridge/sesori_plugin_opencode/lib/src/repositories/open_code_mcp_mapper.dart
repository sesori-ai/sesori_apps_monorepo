import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/openapi/mcpstatus.g.dart";
import "../models/openapi/mcpstatus_connected.g.dart";
import "../models/openapi/mcpstatus_disabled.g.dart";
import "../models/openapi/mcpstatus_failed.g.dart";
import "../models/openapi/mcpstatus_needs_auth.g.dart";
import "../models/openapi/mcpstatus_needs_client_registration.g.dart";

/// Projects the v1 name-keyed native status map without reading configuration.
class const OpenCodeMcpMapper() {
  PluginMcpInventorySnapshot map({required Map<String, MCPStatus> servers, required PluginMcpScope scope}) {
    final names = servers.keys.toList()..sort();
    return PluginMcpInventorySnapshot(
      servers: const PluginMcpCatalogAvailable(),
      connectors: const PluginMcpCatalogNotSupported(),
      entries: List.unmodifiable([
        for (final name in names) _server(name: name, status: servers[name]!, scope: scope),
      ]),
    );
  }

  PluginMcpServerSnapshot _server({required String name, required MCPStatus status, required PluginMcpScope scope}) {
    final actions = switch (status) {
      MCPStatusDisabled() => const [PluginMcpServerAction.enable],
      MCPStatusConnected() || MCPStatusFailed() || MCPStatusNeedsAuth() || MCPStatusNeedsClientRegistration() => const [
        PluginMcpServerAction.reconnect,
        PluginMcpServerAction.disable,
      ],
      _ => const <PluginMcpServerAction>[],
    };
    return PluginMcpServerSnapshot(
      target: PluginMcpServerTarget(scope: scope, serverKey: name),
      name: name,
      description: null,
      endpointOrigin: null,
      configuration: null,
      authorization: status is MCPStatusNeedsAuth || status is MCPStatusNeedsClientRegistration
          ? PluginMcpAuthorizationState.required
          : PluginMcpAuthorizationState.unknown,
      authentication: PluginMcpAuthenticationCapabilityUnavailable(
        reason: status is MCPStatusNeedsClientRegistration
            ? PluginMcpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired
            : PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented,
      ),
      credentialForgetting: const PluginMcpAuthenticationCapabilityUnavailable(
        reason: PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented,
      ),
      actions: List.unmodifiable([
        for (final action in actions)
          PluginMcpServerActionCapability(action: action, effectScope: PluginMcpActionEffectScope.project),
      ]),
      connection: switch (status) {
        MCPStatusConnected() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connected),
        MCPStatusDisabled() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.disabled),
        MCPStatusNeedsAuth() || MCPStatusNeedsClientRegistration() => const PluginMcpConnectionStatus(
          phase: PluginMcpConnectionPhase.authenticationRequired,
        ),
        MCPStatusFailed() => const PluginMcpConnectionFailed(message: "The MCP server failed to connect."),
        _ => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.unknown),
      },
      tools: const PluginMcpToolsUnavailable(),
    );
  }
}
