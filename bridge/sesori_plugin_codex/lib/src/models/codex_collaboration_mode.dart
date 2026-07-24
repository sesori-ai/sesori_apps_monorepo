enum CodexCollaborationMode {
  defaultMode(
    agentName: "Default",
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

  const CodexCollaborationMode({
    required this.agentName,
    required this.wireValue,
    required this.description,
    required this.defaultReasoningEffort,
  });

  final String agentName;
  final String wireValue;
  final String description;
  final String? defaultReasoningEffort;

  static CodexCollaborationMode? fromAgent({required String? agent}) {
    final normalized = agent?.trim().toLowerCase();
    return switch (normalized) {
      // COMPATIBILITY 2026-07-24 (v1.6.0): Older apps omit the agent and
      // expect normal execution. Remove this mapping when those app versions
      // are no longer supported.
      null => defaultMode,
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
