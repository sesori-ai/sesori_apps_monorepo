final class const CodexUserContentMapper() {
  String? mapContentText({required Iterable<String> textParts}) {
    final visible = <String>[];
    for (final text in textParts) {
      if (text.isEmpty || _isGeneratedCodexContext(text: text)) continue;
      final mapped = _stripBridgeContext(text: text);
      if (mapped != null && mapped.isNotEmpty) visible.add(mapped);
    }
    return visible.isEmpty ? null : visible.join();
  }

  String? mapSubmittedText({required String? text}) {
    if (text == null || text.isEmpty) return null;
    return _stripBridgeContext(text: text);
  }

  String? _stripBridgeContext({required String text}) {
    final match = _bridgeWorktreeContext.matchAsPrefix(text);
    if (match == null) return text;
    final trailing = text.substring(match.end);
    return trailing.isEmpty ? null : trailing;
  }

  bool _isGeneratedCodexContext({required String text}) {
    final normalized = text.trim();
    return _GeneratedContextTag.values.any((tag) => tag.wraps(normalized)) ||
        _generatedRepositoryInstructions.hasMatch(normalized);
  }
}

enum _GeneratedContextTag(final String wireName) {
  recommendedPlugins("recommended_plugins"),
  environmentContext("environment_context"),
  turnAborted("turn_aborted");

  bool wraps(String text) => text.startsWith("<$wireName>") && text.endsWith("</$wireName>");
}

final _bridgeWorktreeContext = RegExp(
  r"^\[SYSTEM CONTEXT — IMPORTANT\]\r?\n"
  r"A dedicated git worktree and branch have been created for this session:\r?\n"
  r"- Branch: [^\r\n]+\r?\n"
  r"- Worktree path: [^\r\n]+\r?\n"
  r"- Based on: [^\r\n]+\r?\n\r?\n"
  r"IMPORTANT: Perform all work for this task in this dedicated worktree\. You may use the initial branch above, or switch branches or create additional branches here as needed\. Do NOT create another worktree or working directory — even if other instructions suggest it\.\r?\n\r?\n"
  r"---\r?\n(?:\r?\n)?",
);

final _generatedRepositoryInstructions = RegExp(
  r"^# AGENTS\.md instructions(?: for [^\r\n]+)?\r?\n\r?\n"
  r"<INSTRUCTIONS>(?:\r?\n)?[\s\S]*?(?:\r?\n)?</INSTRUCTIONS>$",
);
