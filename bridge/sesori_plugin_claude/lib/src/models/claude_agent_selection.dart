import "claude_permission_mode.dart";

/// Permission-mode choices a client can name as the agent. Only [standard] is
/// advertised.
enum ClaudeAgentSelection({
  required final String displayName,
  required final String description,
  required final ClaudePermissionMode permissionMode,
}) {
  standard(
    displayName: "Agent",
    description: "Executes tasks and asks before sensitive operations",
    permissionMode: ClaudePermissionMode.standard,
  ),
  // COMPATIBILITY 2026-09-21 (v1.9.0): Plan is no longer advertised as an agent,
  // but stored session and new-session defaults can still name it, and public
  // apps older than v1.8.3 send a stored agent without checking the catalog. It
  // is honoured rather than run in the editing default. Remove once those apps
  // are unsupported and no stored default can still name Plan.
  plan(
    displayName: "Plan",
    description: "Researches without making changes and creates an implementation plan",
    permissionMode: ClaudePermissionMode.plan,
  );

  /// The agent recorded on assistant and error messages. It must stay a
  /// selectable agent: the bridge resends the latest message's agent, for
  /// example when it auto-continues after a usage limit.
  static String get messageAgent => standard.displayName;

  static ClaudeAgentSelection? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final selection in values) {
      if (selection.displayName.toLowerCase() == normalized) return selection;
    }
    return null;
  }
}
