final class const ClaudeMcpCommandExitedException({required final int exitCode}) implements Exception {
  @override
  String toString() => "Claude MCP command exited with code $exitCode";
}
