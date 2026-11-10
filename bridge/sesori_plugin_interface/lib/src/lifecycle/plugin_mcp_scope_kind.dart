/// A kind of MCP location a started plugin answers inventory for.
enum PluginMcpScopeKind() {
  /// The harness's global MCP configuration, without a project or session.
  harness,

  /// One project's MCP configuration.
  project,

  /// One existing session's MCP servers.
  session,
}
