import "claude_permission_mode.dart";

/// Permission-mode choices surfaced through Sesori's agent picker.
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
