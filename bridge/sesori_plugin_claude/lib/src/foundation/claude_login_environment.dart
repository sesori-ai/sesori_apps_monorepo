/// Environment overrides for the `claude auth login` child process.
abstract final class ClaudeLoginEnvironment() {
  /// The CLI treats `BROWSER=true` as "no browser", so login never opens a tab
  /// on the bridge host. It spawns `BROWSER` as one executable without a shell,
  /// so the same value holds on every platform. Windows is unverified.
  static const Map<String, String> overrides = {"BROWSER": "true"};
}
