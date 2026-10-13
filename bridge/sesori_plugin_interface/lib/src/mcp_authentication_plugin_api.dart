import "models/plugin_mcp.dart";
import "models/plugin_mcp_authentication.dart";

/// Explicit authentication for an existing native-configured server.
/// No provider-account login, server creation, or Sesori credential store.
abstract interface class McpAuthenticationPluginApi() {
  Future<PluginMcpAuthenticationOperation> beginMcpAuthentication({required PluginMcpServerTarget target});

  /// Clears native credentials only. It does not disable or remove configuration.
  Future<void> forgetMcpAuthentication({required PluginMcpServerTarget target});
}
