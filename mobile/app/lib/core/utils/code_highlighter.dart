import "package:flutter/material.dart";

import "syntax_highlight.dart";

/// Brightness-aware syntax highlighter for whole fenced code blocks.
///
/// Unlike the line-oriented [DiffHighlighter] (which warns against being
/// called inside an `itemBuilder`), this highlights an entire multi-line
/// block in a single pass, so it is safe to call from a widget `build`.
/// Both share their grammar set, theme and render mechanics via
/// `syntax_highlight.dart`; the classes stay separate because the diff path
/// has a different (line-by-line, pre-computed) usage contract and its own
/// brittle init-order test.
class CodeHighlighter {
  CodeHighlighter._();

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

  static final _highlight = buildSyntaxHighlight();

  /// Maps a fence-info string to a registered language key, or null when the
  /// language is unknown/unsupported (caller falls back to plain monospace).
  static String? _resolve(String? language) {
    if (language == null) return null;
    final normalized = language.toLowerCase().trim();
    if (normalized.isEmpty) return null;
    final mapped = _aliases[normalized] ?? normalized;
    return kSyntaxLanguages.containsKey(mapped) ? mapped : null;
  }

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
    return renderHighlightedSpan(
      highlight: _highlight,
      code: code,
      language: resolved,
      baseStyle: baseStyle,
      theme: githubThemeFor(brightness),
    );
  }
}
