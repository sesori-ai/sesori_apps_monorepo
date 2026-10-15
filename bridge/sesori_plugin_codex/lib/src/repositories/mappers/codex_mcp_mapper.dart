import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/codex_mcp_status_dto.dart";

/// Native presentation metadata only; configuration and execution stay native.
class const CodexMcpMapper() {
  PluginMcpInventorySnapshot map({required List<CodexMcpServerStatusDto> servers, required PluginMcpScope scope}) {
    final sorted = servers.toList()..sort((a, b) => a.name.compareTo(b.name));
    return PluginMcpInventorySnapshot(
      servers: const PluginMcpCatalogAvailable(),
      connectors: const PluginMcpCatalogUnavailable(message: "Codex connector inventory is not implemented yet."),
      entries: List.unmodifiable(sorted.map((server) => _server(server: server, scope: scope))),
    );
  }

  PluginMcpServerSnapshot _server({required CodexMcpServerStatusDto server, required PluginMcpScope scope}) =>
      PluginMcpServerSnapshot(
        target: PluginMcpServerTarget(scope: scope, serverKey: server.name),
        name: _present(value: server.serverInfo?.title) ?? server.name,
        description: _present(value: server.serverInfo?.description),
        endpointOrigin: _origin(value: server.httpOrigin),
        configuration: null,
        authorization: switch (server.authStatus) {
          CodexMcpAuthStatus.oAuth || CodexMcpAuthStatus.bearerToken => PluginMcpAuthorizationState.authenticated,
          CodexMcpAuthStatus.notLoggedIn => PluginMcpAuthorizationState.required,
          CodexMcpAuthStatus.unknown || CodexMcpAuthStatus.unsupported => PluginMcpAuthorizationState.unknown,
        },
        authentication: PluginMcpAuthenticationCapabilityUnavailable(
          reason: server.authStatus == CodexMcpAuthStatus.unsupported
              ? PluginMcpAuthenticationCapabilityUnavailableReason.notSupported
              : PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented,
        ),
        credentialForgetting: const PluginMcpAuthenticationCapabilityUnavailable(
          reason: PluginMcpAuthenticationCapabilityUnavailableReason.notSupported,
        ),
        actions: const [],
        connection: switch (server.runtimeStatus) {
          null ||
          CodexMcpRuntimeStatus.unknown => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.unknown),
          CodexMcpRuntimeStatus.notStarted => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.pending),
          CodexMcpRuntimeStatus.starting => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connecting),
          CodexMcpRuntimeStatus.connected => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connected),
          CodexMcpRuntimeStatus.authenticationRequired => const PluginMcpConnectionStatus(
            phase: PluginMcpConnectionPhase.authenticationRequired,
          ),
          CodexMcpRuntimeStatus.disabled => const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.disabled),
          CodexMcpRuntimeStatus.failed => const PluginMcpConnectionFailed(message: "The MCP server failed to connect."),
          CodexMcpRuntimeStatus.cancelled => const PluginMcpConnectionFailed(
            message: "The MCP server connection was cancelled.",
          ),
        },
        tools: server.toolsError != null
            ? const PluginMcpToolsFailed(message: "MCP tool discovery is unavailable.")
            : server.tools.isNotEmpty || server.runtimeStatus == CodexMcpRuntimeStatus.connected
            ? PluginMcpToolsAvailable(
                tools: List.unmodifiable(
                  server.tools.values.map(
                    (tool) => PluginMcpTool(
                      name: tool.name,
                      description: _present(value: tool.description),
                    ),
                  ),
                ),
              )
            : const PluginMcpToolsUnavailable(),
      );

  String? _present({required String? value}) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _origin({required String? value}) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty || (uri.scheme != "http" && uri.scheme != "https")) {
      return null;
    }
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null).toString();
  }
}
