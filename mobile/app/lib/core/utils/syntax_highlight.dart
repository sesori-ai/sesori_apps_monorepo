import "package:flutter/material.dart";
import "package:re_highlight/languages/css.dart";
import "package:re_highlight/languages/dart.dart";
import "package:re_highlight/languages/go.dart";
import "package:re_highlight/languages/java.dart";
import "package:re_highlight/languages/javascript.dart";
import "package:re_highlight/languages/json.dart";
import "package:re_highlight/languages/kotlin.dart";
import "package:re_highlight/languages/python.dart";
import "package:re_highlight/languages/rust.dart";
import "package:re_highlight/languages/sql.dart";
import "package:re_highlight/languages/swift.dart";
import "package:re_highlight/languages/typescript.dart";
import "package:re_highlight/languages/xml.dart";
import "package:re_highlight/languages/yaml.dart";
import "package:re_highlight/re_highlight.dart";
import "package:re_highlight/styles/github-dark.dart";
import "package:re_highlight/styles/github.dart";

/// Shared `re_highlight` foundation for the app's two syntax highlighters: the
/// whole-block [CodeHighlighter] (chat/markdown code fences) and the
/// line-oriented [DiffHighlighter] (session diffs).
///
/// The two stay as separate classes because their usage contracts differ — the
/// block path highlights an entire fence lazily in one pass, while the diff
/// path is pre-initialized eagerly and highlights line-by-line (never inside an
/// `itemBuilder`, and with a strict init-order test). But the grammar set,
/// theme and render mechanics are identical, so they live here once and the two
/// highlighters can never drift apart (e.g. a language added to only one map).

/// Grammars keyed by the normalized language name each highlighter resolves to.
final Map<String, Mode> kSyntaxLanguages = <String, Mode>{
  "dart": langDart,
  "typescript": langTypescript,
  "javascript": langJavascript,
  "python": langPython,
  "go": langGo,
  "java": langJava,
  "kotlin": langKotlin,
  "swift": langSwift,
  "rust": langRust,
  "html": langXml,
  "css": langCss,
  "json": langJson,
  "yaml": langYaml,
  "sql": langSql,
};

/// Builds a [Highlight] with every [kSyntaxLanguages] grammar registered.
Highlight buildSyntaxHighlight() {
  final highlight = Highlight();
  kSyntaxLanguages.forEach(highlight.registerLanguage);
  return highlight;
}

/// The GitHub light/dark token theme matching [brightness].
Map<String, TextStyle> githubThemeFor(Brightness brightness) =>
    brightness == Brightness.dark ? githubDarkTheme : githubTheme;

/// Renders [code] in [language] to a themed [TextSpan], or null on any grammar
/// error so callers can fall back to plain text. [language] must already be a
/// key registered in [highlight]; [baseStyle] supplies the font and default
/// colour for untokenized text, while per-token colours come from [theme].
TextSpan? renderHighlightedSpan({
  required Highlight highlight,
  required String code,
  required String language,
  required TextStyle baseStyle,
  required Map<String, TextStyle> theme,
}) {
  try {
    final result = highlight.highlight(code: code, language: language);
    final renderer = TextSpanRenderer(baseStyle, theme);
    result.render(renderer);
    return renderer.span;
  } catch (_) {
    return null; // Graceful fallback for grammar edge cases.
  }
}
