import "models/plugin_mcp.dart";
import "models/plugin_mcp_authentication.dart";

/// Explicit authentication for an existing native-configured server.
/// No provider-account login, server creation, or Sesori credential store.
abstract interface class McpAuthenticationPluginApi() {
  /// Resolves read-only context. Native authentication starts only when the
  /// returned operation's events are subscribed. Callers may discard an operation
  /// before subscribing when preparation was cancelled; it must start no work.
  Future<PluginMcpAuthenticationOperation> beginMcpAuthentication({required PluginMcpServerTarget target});

  /// Clears native credentials only. It does not disable or remove configuration.
  /// Returns the native credential scope affected, for inventory invalidation.
  Future<PluginMcpActionEffectScope> forgetMcpAuthentication({required PluginMcpServerTarget target});
}
