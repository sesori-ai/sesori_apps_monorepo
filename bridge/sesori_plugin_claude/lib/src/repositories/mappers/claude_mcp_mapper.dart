import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/claude_mcp_status_dto.dart";

/// Projects only presentation-safe native inventory fields into the contract.
class const ClaudeMcpMapper() {
  PluginMcpInventorySnapshot map({required ClaudeMcpStatusDto status, required PluginMcpSessionScope scope}) {
    final servers = status.mcpServers.toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));
    return PluginMcpInventorySnapshot(
      servers: const PluginMcpCatalogAvailable(),
      entries: List.unmodifiable(servers.map((server) => _server(server: server, scope: scope))),
      connectors: const PluginMcpCatalogUnavailable(
        message: "This integration does not yet expose a connector catalog.",
      ),
    );
  }

  PluginMcpServerSnapshot _server({required ClaudeMcpServerStatusDto server, required PluginMcpSessionScope scope}) {
    final title = _presentText(value: server.serverInfo?.title);
    return PluginMcpServerSnapshot(
      target: PluginMcpServerTarget(scope: scope, serverKey: server.name),
      actions: const [
        PluginMcpServerActionCapability(
          action: PluginMcpServerAction.reconnect,
          effectScope: PluginMcpActionEffectScope.session,
        ),
        PluginMcpServerActionCapability(
          action: PluginMcpServerAction.enable,
          effectScope: PluginMcpActionEffectScope.session,
        ),
        PluginMcpServerActionCapability(
          action: PluginMcpServerAction.disable,
          effectScope: PluginMcpActionEffectScope.session,
        ),
      ],
      name: title ?? server.name,
      description: _presentText(value: server.serverInfo?.description),
      endpointOrigin: _endpointOrigin(value: server.config?.url),
      connection: switch (server.status) {
        ClaudeMcpStatus.unknown => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.unknown),
        ClaudeMcpStatus.pending => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.pending),
        ClaudeMcpStatus.connected => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connected),
        ClaudeMcpStatus.disabled => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.disabled),
        ClaudeMcpStatus.needsAuth => const PluginMcpConnectionStatus(
          phase: PluginMcpConnectionPhase.authenticationRequired,
        ),
        ClaudeMcpStatus.failed => const PluginMcpConnectionFailed(message: "The MCP server failed to connect."),
      },
      authorization: switch (server.status) {
        ClaudeMcpStatus.needsAuth => PluginMcpAuthorizationState.required,
        _ => PluginMcpAuthorizationState.unknown,
      },
      configuration: _configuration(scope: server.scope),
      tools: switch ((server.tools, server.status)) {
        (final tools?, _) when tools.isNotEmpty => PluginMcpToolsAvailable(
          tools: List.unmodifiable(
            tools.map(
              (tool) => PluginMcpTool(
                name: tool.name,
                description: _presentText(value: tool.description),
              ),
            ),
          ),
        ),
        (_, ClaudeMcpStatus.failed) => const PluginMcpToolsFailed(message: "MCP tool discovery is unavailable."),
        ([], ClaudeMcpStatus.connected) => const PluginMcpToolsAvailable(tools: []),
        _ => const PluginMcpToolsUnavailable(),
      },
    );
  }

  PluginMcpConfigurationSource? _configuration({required ClaudeMcpConfigurationScope? scope}) => switch (scope) {
    null || ClaudeMcpConfigurationScope.unknown => null,
    ClaudeMcpConfigurationScope.user => const PluginMcpConfigurationSource(
      scope: PluginMcpConfigurationScope.harness,
      mutability: PluginMcpConfigurationMutability.userManaged,
    ),
    ClaudeMcpConfigurationScope.local || ClaudeMcpConfigurationScope.project => const PluginMcpConfigurationSource(
      scope: PluginMcpConfigurationScope.project,
      mutability: PluginMcpConfigurationMutability.userManaged,
    ),
    ClaudeMcpConfigurationScope.dynamic => const PluginMcpConfigurationSource(
      scope: PluginMcpConfigurationScope.session,
      mutability: PluginMcpConfigurationMutability.unknown,
    ),
    ClaudeMcpConfigurationScope.managed => const PluginMcpConfigurationSource(
      scope: PluginMcpConfigurationScope.harness,
      mutability: PluginMcpConfigurationMutability.readOnly,
    ),
  };

  String? _endpointOrigin({required String? value}) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty || (uri.scheme != "https" && uri.scheme != "http")) {
      return null;
    }
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null).toString();
  }

  String? _presentText({required String? value}) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
