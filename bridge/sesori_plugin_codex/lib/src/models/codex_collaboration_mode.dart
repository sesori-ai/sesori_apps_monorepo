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
      // COMPATIBILITY 2026-07-24 (v1.6.0): Older apps omit the agent and
      // expect normal execution. Remove this mapping when those app versions
      // are no longer supported.
      null => defaultMode,
      "agent" => defaultMode,
      // COMPATIBILITY 2026-08-19 (v1.7.0): This mode was named "Default" until
      // it was renamed to "Agent". Remove once no supported app can send it.
      "default" => defaultMode,
      "plan" => plan,
      // COMPATIBILITY 2026-07-24 (v1.6.0): Earlier Codex plugins persisted
      // their sole agent as "codex". Remove this alias after v1.6.0 prompt
      // defaults are no longer supported.
      "codex" => defaultMode,
      _ => null,
    };
  }
}
