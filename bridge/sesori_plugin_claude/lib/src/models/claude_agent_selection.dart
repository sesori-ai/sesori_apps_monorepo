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
  // COMPATIBILITY 2026-09-21 (v1.9.0): Plan was advertised as an agent, and catalogs
  // captured then are served for up to 30 days, so a client can still send it.
  // It is honoured rather than run in the editing default. Remove once no
  // catalog captured before this date can still be served.
  plan(
    displayName: "Plan",
    description: "Researches without making changes and creates an implementation plan",
    permissionMode: ClaudePermissionMode.plan,
  );

  static ClaudeAgentSelection? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final selection in values) {
      if (selection.displayName.toLowerCase() == normalized) return selection;
    }
    return null;
  }
}
