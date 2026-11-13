/// What a Claude process is started for.
enum ClaudeProcessPurpose() {
  /// A user session that runs turns.
  session,

  /// A catalog probe that only reads the startup handshake. It runs in a
  /// project's directory so the CLI lists that project's commands and skills,
  /// and it must not act on the project: it starts no hooks and no MCP servers.
  catalogProbe,
}
