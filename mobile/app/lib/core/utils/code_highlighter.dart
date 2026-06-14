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

/// Brightness-aware syntax highlighter for whole fenced code blocks.
///
/// Unlike the line-oriented [DiffHighlighter] (which warns against being
/// called inside an `itemBuilder`), this highlights an entire multi-line
/// block in a single pass, so it is safe to call from a widget `build`.
/// The grammar set mirrors [DiffHighlighter]; the two are intentionally kept
/// separate because the diff path has a different (line-by-line, pre-computed)
/// usage contract and its own brittle init-order test.
class CodeHighlighter {
  CodeHighlighter._();

  /// Languages keyed by the normalized name [_resolve] returns.
  static final Map<String, Mode> _languages = <String, Mode>{
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

  /// Common fence aliases mapped to a registered language key.
  static const Map<String, String> _aliases = <String, String>{
    "js": "javascript",
    "jsx": "javascript",
    "ts": "typescript",
    "tsx": "typescript",
    "py": "python",
    "rs": "rust",
    "kt": "kotlin",
    "yml": "yaml",
    "xml": "html",
    "golang": "go",
  };

  static final Highlight _highlight = _buildHighlight();

  static Highlight _buildHighlight() {
    final highlight = Highlight();
    _languages.forEach(highlight.registerLanguage);
    return highlight;
  }

  /// Maps a fence-info string to a registered language key, or null when the
  /// language is unknown/unsupported (caller falls back to plain monospace).
  static String? _resolve(String? language) {
    if (language == null) return null;
    final normalized = language.toLowerCase().trim();
    if (normalized.isEmpty) return null;
    final mapped = _aliases[normalized] ?? normalized;
    return _languages.containsKey(mapped) ? mapped : null;
  }

  /// True when [language] resolves to a grammar we can highlight.
  static bool supports(String? language) => _resolve(language) != null;

  /// Returns a highlighted [TextSpan] for [code], or null when the language is
  /// unknown/unsupported. [baseStyle] supplies the font and default colour for
  /// untokenized text; per-token colours come from the GitHub light/dark theme
  /// chosen by [brightness].
  static TextSpan? highlight({
    required String code,
    required String? language,
    required Brightness brightness,
    required TextStyle baseStyle,
  }) {
    final resolved = _resolve(language);
    if (resolved == null) return null;
    try {
      final result = _highlight.highlight(code: code, language: resolved);
      final theme = brightness == Brightness.dark ? githubDarkTheme : githubTheme;
      final renderer = TextSpanRenderer(baseStyle, theme);
      result.render(renderer);
      return renderer.span;
    } catch (_) {
      return null; // Graceful fallback for grammar edge cases.
    }
  }
}
