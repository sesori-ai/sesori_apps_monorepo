/// Reasoning effort for a Claude session.
///
/// Effort support is declared per model: the `initialize` control response
/// carries `supportsEffort` and `supportedEffortLevels` for each catalog entry,
/// and models that do not support it omit both fields. Never assume the full
/// set is available for a given model.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 4.
enum ClaudeEffortLevel {
  low,
  medium,
  high,
  xhigh,
  max;

  /// Value accepted by the `--effort` command-line flag and reported back on
  /// transcript `assistant` records.
  String get wireValue => name;

  /// Parses a level at the wire boundary.
  ///
  /// Returns null for an unrecognized value so a newer CLI's level does not
  /// throw; callers fall back to the model's declared default.
  static ClaudeEffortLevel? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    for (final level in ClaudeEffortLevel.values) {
      if (level.wireValue == trimmed) return level;
    }
    return null;
  }
}
