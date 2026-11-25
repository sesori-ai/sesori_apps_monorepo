/// A tool group's long how-to: the single source of both the skill the
/// bridge writes for harnesses that load skills and the `get_guide` answer
/// for those that don't.
final class const SesoriToolGuide({
  /// The skill's name, lowercase with dashes, such as `pr-monitor`. Harnesses
  /// see it as `sesori-pr-monitor`, or `sesori:pr-monitor` in Claude Code.
  required final String name,

  /// When to load the guide, in one sentence: the skill's `description` and
  /// the topic's line in `get_guide`.
  required final String whenToUse,

  /// The how-to itself, in Markdown, without a skill's frontmatter.
  required final String body,
});
