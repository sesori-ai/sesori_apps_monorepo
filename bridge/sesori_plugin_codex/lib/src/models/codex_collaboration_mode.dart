enum CodexCollaborationMode({
  required final String agentName,
  required final String wireValue,
  required final String description,
  required final String? defaultReasoningEffort,
}) {
  defaultMode(
    agentName: "Agent",
    wireValue: "default",
    description: "Executes tasks, making project changes when needed",
    defaultReasoningEffort: null,
  ),
  plan(
    agentName: "Plan",
    wireValue: "plan",
    description: "Researches without making changes and creates an implementation plan",
    defaultReasoningEffort: "medium",
  );

  static CodexCollaborationMode? fromAgent({required String? agent}) {
    final normalized = agent?.trim().toLowerCase();
    return switch (normalized) {
      null => defaultMode,
      "agent" => defaultMode,
      // COMPATIBILITY 2026-08-19 (v1.7.0): This mode was named "Default" until
      // it was renamed to "Agent". Remove once no supported app can send it.
      "default" => defaultMode,
      // COMPATIBILITY 2026-09-21 (v1.9.0): Plan is no longer advertised as an
      // agent, but stored session and new-session defaults can still name it,
      // and public apps older than v1.8.3 send a stored agent without checking
      // the catalog. It is honoured rather than run in the editing default.
      // Remove once those apps are unsupported and no stored default can still
      // name Plan.
      "plan" => plan,
      // Codex history reports "codex" as each message's agent, and the bridge
      // resends the latest one, for example when continuing after a usage limit.
      "codex" => defaultMode,
      _ => null,
    };
  }
}
