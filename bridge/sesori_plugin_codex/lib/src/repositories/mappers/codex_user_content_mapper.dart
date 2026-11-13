import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

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

  /// Shows a picked skill as the user typed it, `/name args`. Codex records
  /// the invocation as `\$name args` text plus a `skill` input naming it, so
  /// only text that starts with a named skill's `\$name` is rewritten.
  String? mapSkillInvocation({required String? text, required List<String> skillNames}) {
    if (text == null) return null;
    return switch (_skillCall(text: text, skillNames: skillNames)) {
      (:final name, :final rest) => "/$name$rest",
      null => text,
    };
  }

  /// The skill run that [text] starts, named from the `skill` inputs Codex
  /// recorded with it, or null when the message ran none.
  PluginCommandInvocation? mapCommandInvocation({required String? text, required List<String> skillNames}) {
    if (text == null) return null;
    return switch (_skillCall(text: text, skillNames: skillNames)) {
      (:final name, :final rest) => PluginCommandInvocation(
        name: name,
        source: PluginCommandSource.skill,
        arguments: rest.trim().isEmpty ? null : rest.trim(),
      ),
      null => null,
    };
  }

  ({String name, String rest})? _skillCall({required String text, required List<String> skillNames}) {
    for (final name in skillNames) {
      final token = "\$$name";
      if (!text.startsWith(token)) continue;
      final rest = text.substring(token.length);
      if (rest.isEmpty || rest.startsWith(RegExp(r"\s"))) return (name: name, rest: rest);
    }
    return null;
  }

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
  turnAborted("turn_aborted"),

  /// A picked skill's `SKILL.md` body, which Codex injects as a user message
  /// after the `\$name` text the user's bubble already shows.
  skill("skill"),

  /// A `multi_agent_v1` child's completion, which Codex hands the parent as a
  /// user message; the child's subtask tile already shows it.
  subagentNotification("subagent_notification");

  bool wraps({required String text}) => text.startsWith("<$wireName>") && text.endsWith("</$wireName>");
}

final _generatedRepositoryInstructions = RegExp(
  r"^# AGENTS\.md instructions(?: for [^\r\n]+)?\r?\n\r?\n"
  r"<INSTRUCTIONS>(?:\r?\n)?[\s\S]*?(?:\r?\n)?</INSTRUCTIONS>$",
);

/// The text items Codex writes around a `localImage` input, as in
/// `<image name=[Image #1] path="/x.png">`, the image, then `</image>`.
final _generatedLocalImageTag = RegExp(r'^(?:<image name=\[Image #\d+\](?: path=".*")?>|</image>)$');
