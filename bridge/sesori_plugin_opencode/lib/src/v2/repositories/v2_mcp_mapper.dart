import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/openapi/mcp_server.g.dart";
import "../models/openapi/mcp_status_connected.g.dart";
import "../models/openapi/mcp_status_disabled.g.dart";
import "../models/openapi/mcp_status_failed.g.dart";
import "../models/openapi/mcp_status_needs_auth.g.dart";
import "../models/openapi/mcp_status_pending.g.dart";

/// Native location metadata only; neither credentials nor configuration escape.
class const V2McpMapper() {
  PluginMcpInventorySnapshot map({required List<McpServer> servers, required PluginMcpScope scope}) {
    final sorted = servers.toList()..sort((a, b) => a.name.compareTo(b.name));
    return PluginMcpInventorySnapshot(
      servers: const PluginMcpCatalogAvailable(),
      connectors: const PluginMcpCatalogNotSupported(),
      entries: List.unmodifiable(sorted.map((server) => _server(server: server, scope: scope))),
    );
  }

  PluginMcpServerSnapshot _server({required McpServer server, required PluginMcpScope scope}) {
    final status = server.status;
    final authentication = server.integrationID == null
        ? const PluginMcpAuthenticationCapabilityUnavailable(
            reason: PluginMcpAuthenticationCapabilityUnavailableReason.notSupported,
          )
        : const PluginMcpAuthenticationCapabilityAvailable(effectScope: PluginMcpActionEffectScope.harness);
    final actions = switch (status) {
      McpStatusDisabled() => const [PluginMcpServerAction.enable],
      McpStatusConnected() || McpStatusPending() || McpStatusFailed() || McpStatusNeedsAuth() => const [
        PluginMcpServerAction.reconnect,
        PluginMcpServerAction.disable,
      ],
      _ => const <PluginMcpServerAction>[],
    };
    return PluginMcpServerSnapshot(
      target: PluginMcpServerTarget(scope: scope, serverKey: server.name),
      name: server.name,
      description: null,
      endpointOrigin: null,
      configuration: null,
      authorization: status is McpStatusNeedsAuth
          ? PluginMcpAuthorizationState.required
          : PluginMcpAuthorizationState.unknown,
      authentication: authentication,
      credentialForgetting: authentication,
      actions: List.unmodifiable([
        for (final action in actions)
          PluginMcpServerActionCapability(action: action, effectScope: PluginMcpActionEffectScope.project),
      ]),
      connection: switch (status) {
        McpStatusConnected() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connected),
        McpStatusPending() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.pending),
        McpStatusDisabled() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.disabled),
        McpStatusNeedsAuth() => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.authenticationRequired),
        McpStatusFailed() => const PluginMcpConnectionFailed(message: "The MCP server failed to connect."),
        _ => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.unknown),
      },
      tools: const PluginMcpToolsUnavailable(),
    );
  }
}
