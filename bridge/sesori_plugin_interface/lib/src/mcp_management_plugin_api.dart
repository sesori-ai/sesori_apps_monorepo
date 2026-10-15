import "models/plugin_mcp.dart";

/// Optional native MCP inventory capability. Reads must not create/resume an
/// agent session, authenticate a server, execute a tool, or write configuration.
/// Backend credentials and configuration always remain harness-owned.
abstract interface class McpManagementPluginApi() {
  Future<PluginMcpInventoryResult> getMcpInventory({required PluginMcpScope scope});

  /// Explicit controls on an existing target. Must not implicitly start a session.
  Future<PluginMcpActionResult> executeMcpServerAction({
    required PluginMcpServerTarget target,
    required PluginMcpServerAction action,
  });
}
