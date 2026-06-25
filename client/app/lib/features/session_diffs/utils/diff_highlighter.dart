import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/extensions/text_style_x.dart';
import '../../../core/utils/syntax_highlight.dart';

/// Static helper for syntax highlighting diff lines.
/// Must call [initialize] once before using [highlightLine].
///
/// Shares its grammar set, theme and render mechanics with the whole-block
/// [CodeHighlighter] via `core/utils/syntax_highlight.dart`. It is kept as a
/// separate class because diffs are highlighted line-by-line and the grammars
/// must be registered eagerly up front (never lazily inside an `itemBuilder`),
/// which gives it the strict init-order contract exercised by its tests.
class DiffHighlighter {
  static Highlight? _highlight;
  static late Map<String, TextStyle> _theme;
  static bool _initialized = false;

  static final _monoStyle = const TextStyle(fontSize: 12).monospace;

  /// Call ONCE before any highlighting. Safe to call multiple times.
  static Future<void> initialize({Brightness brightness = Brightness.light}) async {
    if (_initialized) return;
    _highlight = buildSyntaxHighlight();
    _theme = githubThemeFor(brightness);
    _initialized = true;
  }

  /// Highlight a single line of code. Returns null if language unsupported or
  /// not yet initialized.
  ///
  /// IMPORTANT: Call [initialize] first. Never call this inside an itemBuilder.
  static TextSpan? highlightLine({required String content, required String? language}) {
    final highlight = _highlight;
    if (!_initialized || language == null || highlight == null) return null;
    if (!kSyntaxLanguages.containsKey(language)) return null;
    return renderHighlightedSpan(
      highlight: highlight,
      code: content,
      language: language,
      baseStyle: _monoStyle,
      theme: _theme,
    );
  }
}
