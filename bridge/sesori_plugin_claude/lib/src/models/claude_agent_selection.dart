import "claude_permission_mode.dart";

/// Permission-mode choices surfaced through Sesori's agent picker.
enum ClaudeAgentSelection {
  standard(
    displayName: "Default",
    description: "Executes tasks and asks before sensitive operations",
    permissionMode: ClaudePermissionMode.standard,
  ),
  plan(
    displayName: "Plan",
    description: "Researches without making changes and creates an implementation plan",
    permissionMode: ClaudePermissionMode.plan,
  );

  ClaudeAgentSelection({
    required this.displayName,
    required this.description,
    required this.permissionMode,
  });

  final String displayName;
  final String description;
  final ClaudePermissionMode permissionMode;

  static ClaudeAgentSelection? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final selection in values) {
      if (selection.displayName.toLowerCase() == normalized) return selection;
    }
    return null;
  }
}
