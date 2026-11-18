/// A private `--mcp-config` file that hands one Claude launch Sesori's server.
final class const ClaudeSesoriMcpConfigFile({
  /// The MCP server name the file declares.
  required final String serverName,

  /// The file's absolute path. It holds the launch's token, so it lives only
  /// until the process has read it.
  required final String path,
});
