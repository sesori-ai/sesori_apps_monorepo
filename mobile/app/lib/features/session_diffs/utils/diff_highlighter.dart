import 'package:flutter/material.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// Static helper for syntax highlighting diff lines.
/// Must call [initialize] once before using [highlightLine].
class DiffHighlighter {
  static HighlighterTheme? _theme;
  static bool _initialized = false;

  // Supported language names (must match syntax_highlight's language IDs).
  static const _supportedLanguages = [
    'dart',
    'typescript',
    'javascript',
    'python',
    'go',
    'java',
    'kotlin',
    'swift',
    'rust',
    'html',
    'css',
    'json',
    'yaml',
    'sql',
  ];

  /// Call ONCE before any highlighting. Safe to call multiple times.
  static Future<void> initialize({Brightness brightness = Brightness.light}) async {
    if (_initialized) return;
    await Highlighter.initialize(_supportedLanguages);
    _theme = brightness == Brightness.dark
        ? await HighlighterTheme.loadDarkTheme()
        : await HighlighterTheme.loadLightTheme();
    _initialized = true;
  }

  /// Highlight a single line of code. Returns null if language unsupported or
  /// not yet initialized.
  ///
  /// IMPORTANT: Call [initialize] first. Never call this inside an itemBuilder.
  static TextSpan? highlightLine(String content, String? language) {
    if (!_initialized || language == null || _theme == null) return null;
    try {
      final highlighter = Highlighter(language: language, theme: _theme!);
      return highlighter.highlight(content);
    } catch (_) {
      return null; // Graceful fallback for unsupported/unknown languages
    }
  }
}
