/// Optional MCP interfaces a started plugin implements.
///
/// Declared on the descriptor so the bridge can tell a harness that never
/// supports MCP from one that supports it but is not running, without
/// starting it.
enum PluginMcpCapability() {
  /// The plugin implements `McpManagementPluginApi`: inventory and server
  /// controls.
  management,

  /// The plugin implements `McpAuthenticationPluginApi`: server sign-in and
  /// credential forgetting.
  authentication,

  /// The plugin implements `McpConnectorSetupPluginApi`: connector setup
  /// links.
  connectorSetup,
}
