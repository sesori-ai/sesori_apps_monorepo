final class const CodexUserContentMapper() {
  String? mapContentText({required Iterable<String> textParts}) {
    final visible = textParts.where((text) => text.isNotEmpty && !_isGeneratedCodexContext(text: text));
    return visible.isEmpty ? null : visible.join();
  }

  String? mapSubmittedText({required String? text}) => text == null || text.isEmpty ? null : text;

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

final _generatedRepositoryInstructions = RegExp(
  r"^# AGENTS\.md instructions(?: for [^\r\n]+)?\r?\n\r?\n"
  r"<INSTRUCTIONS>(?:\r?\n)?[\s\S]*?(?:\r?\n)?</INSTRUCTIONS>$",
);
