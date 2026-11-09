final class const CodexUserContentMapper() {
  /// Joins a user message's text items a blank line apart, as the bridge joins
  /// a prompt's visible texts, so a saved file's note stays its own paragraph.
  String? mapContentText({required Iterable<String> textParts}) {
    final visible = textParts.where((text) => text.isNotEmpty && !_isGeneratedCodexContext(text: text));
    return visible.isEmpty ? null : visible.join("\n\n");
  }

  String? mapSubmittedText({required String? text}) => text == null || text.isEmpty ? null : text;

  /// Joins the text items the user submitted a blank line apart, as
  /// `joinAdjacentPromptTextParts` does: a lone item is kept as it is, and a
  /// run of several drops its blank items. Unlike [mapContentText] it filters
  /// no generated context: a live message holds only what the user sent, so
  /// text shaped like a generated context envelope is theirs.
  String? mapSubmittedTextParts({required List<String> textParts}) => mapSubmittedText(
    text: textParts.length == 1 ? textParts.single : textParts.where((text) => text.trim().isNotEmpty).join("\n\n"),
  );

  bool _isGeneratedCodexContext({required String text}) {
    final normalized = text.trim();
    return _GeneratedContextTag.values.any((tag) => tag.wraps(text: normalized)) ||
        _generatedRepositoryInstructions.hasMatch(normalized) ||
        _generatedLocalImageTag.hasMatch(normalized);
  }
}

enum _GeneratedContextTag(final String wireName) {
  recommendedPlugins("recommended_plugins"),
  environmentContext("environment_context"),
  turnAborted("turn_aborted");

  bool wraps({required String text}) => text.startsWith("<$wireName>") && text.endsWith("</$wireName>");
}

final _generatedRepositoryInstructions = RegExp(
  r"^# AGENTS\.md instructions(?: for [^\r\n]+)?\r?\n\r?\n"
  r"<INSTRUCTIONS>(?:\r?\n)?[\s\S]*?(?:\r?\n)?</INSTRUCTIONS>$",
);

/// The text items Codex writes around a `localImage` input, as in
/// `<image name=[Image #1] path="/x.png">`, the image, then `</image>`.
final _generatedLocalImageTag = RegExp(r'^(?:<image name=\[Image #\d+\](?: path=".*")?>|</image>)$');
