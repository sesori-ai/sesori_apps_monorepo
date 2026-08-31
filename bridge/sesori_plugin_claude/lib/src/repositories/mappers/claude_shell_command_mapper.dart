/// Extracts the command from Claude's Bash tool input without retaining other
/// backend metadata outside the plugin.
abstract final class ClaudeShellCommandMapper() {
  static String? map({required String name, required Object? input}) {
    if (name.toLowerCase() != "bash" || input is! Map) return null;
    final command = input["command"];
    return command is String && command.isNotEmpty ? command : null;
  }
}
