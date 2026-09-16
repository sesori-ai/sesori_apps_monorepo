/// One Claude CLI child process: what to run, where, and which environment
/// entries to merge over the bridge's own environment.
final class ClaudeProcessLaunch({
  /// The `claude` executable: a `--claude-bin` override or a PATH name.
  required final String binaryPath,
  required List<String> arguments,
  required final String workingDirectory,
  required Map<String, String> environment,
}) {
  this {
    if (this.environment.containsKey("HOME")) {
      throw ArgumentError.value(
        this.environment,
        "environment",
        "must not override HOME; use CLAUDE_CONFIG_DIR for isolation",
      );
    }
  }

  /// The argument vector, excluding the executable itself.
  final List<String> arguments = List.unmodifiable(arguments);

  /// Extra environment entries merged over the bridge's own environment.
  ///
  /// `HOME` must never appear here. Overriding it breaks macOS keychain lookup
  /// and makes a logged-in user look logged out. Test isolation uses
  /// `CLAUDE_CONFIG_DIR` instead.
  final Map<String, String> environment = Map.unmodifiable(environment);
}
