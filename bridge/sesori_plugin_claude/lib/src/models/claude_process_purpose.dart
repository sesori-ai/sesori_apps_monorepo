/// What a Claude process is started for.
enum ClaudeProcessPurpose() {
  /// A user session that runs turns.
  session,

  /// A catalog probe that only reads the startup handshake. It runs in a
  /// mirror of a project's command and skill files so the CLI lists them, and
  /// it must not act on the project: it starts no hooks and no MCP servers.
  catalogProbe,
}
