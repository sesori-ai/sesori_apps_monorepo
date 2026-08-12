/// How the Claude CLI decides whether a tool may run.
///
/// The CLI flag and the control protocol disagree on one spelling: the
/// prompt-for-dangerous-operations mode is `manual` on `--permission-mode` and
/// `default` in a `set_permission_mode` control request. Both spellings name
/// the same mode, so this enum owns the translation and no caller hardcodes
/// either string.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 6.
enum ClaudePermissionMode({required this.cliValue, required this.controlValue}) {
  /// Prompts before dangerous operations. `manual` on the CLI, `default` in the
  /// control protocol.
  standard(cliValue: "manual", controlValue: "default"),

  /// Auto-accepts file edits.
  acceptEdits(cliValue: "acceptEdits", controlValue: "acceptEdits"),

  /// Planning mode. Tools that change state do not execute; the model finishes
  /// by proposing a plan through `ExitPlanMode`.
  plan(cliValue: "plan", controlValue: "plan"),

  /// Skips every permission check. Requires the CLI's dangerous-skip opt-in.
  bypassPermissions(cliValue: "bypassPermissions", controlValue: "bypassPermissions"),

  /// Never prompts; denies anything not already permitted.
  dontAsk(cliValue: "dontAsk", controlValue: "dontAsk"),

  /// Uses a model classifier to approve or deny prompts. This is the CLI's own
  /// default when no mode is passed.
  auto(cliValue: "auto", controlValue: "auto");

  /// Spelling accepted by the `--permission-mode` command-line flag.
  final String cliValue;

  /// Spelling accepted by a `set_permission_mode` control request, and reported
  /// back on `system/init.permissionMode` and in transcript records.
  final String controlValue;

  /// Parses either spelling at the wire boundary.
  ///
  /// Returns null for an unrecognized value so callers fail soft rather than
  /// throwing on a mode a newer CLI introduced.
  static ClaudePermissionMode? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    for (final mode in ClaudePermissionMode.values) {
      if (mode.cliValue == trimmed || mode.controlValue == trimmed) return mode;
    }
    return null;
  }
}
