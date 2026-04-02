import 'package:flutter/material.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';

/// Static helper for syntax highlighting diff lines.
/// Must call [initialize] once before using [highlightLine].
class DiffHighlighter {
  static Highlight? _highlight;
  static late Map<String, TextStyle> _theme;
  static bool _initialized = false;

  static const _monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 12);

  /// Language registrations keyed by the name [detectLanguage] returns.
  static final _languages = <String, Mode>{
    'dart': langDart,
    'typescript': langTypescript,
    'javascript': langJavascript,
    'python': langPython,
    'go': langGo,
    'java': langJava,
    'kotlin': langKotlin,
    'swift': langSwift,
    'rust': langRust,
    'html': langXml,
    'css': langCss,
    'json': langJson,
    'yaml': langYaml,
    'sql': langSql,
  };

  /// Call ONCE before any highlighting. Safe to call multiple times.
  static Future<void> initialize({Brightness brightness = Brightness.light}) async {
    if (_initialized) return;
    _highlight = Highlight();
    for (final entry in _languages.entries) {
      _highlight!.registerLanguage(entry.key, entry.value);
    }
    _theme = brightness == Brightness.dark ? githubDarkTheme : githubTheme;
    _initialized = true;
  }

  /// Highlight a single line of code. Returns null if language unsupported or
  /// not yet initialized.
  ///
  /// IMPORTANT: Call [initialize] first. Never call this inside an itemBuilder.
  static TextSpan? highlightLine(String content, String? language) {
    if (!_initialized || language == null || _highlight == null) return null;
    if (!_languages.containsKey(language)) return null;
    try {
      final result = _highlight!.highlight(code: content, language: language);
      final renderer = TextSpanRenderer(_monoStyle, _theme);
      result.render(renderer);
      return renderer.span;
    } catch (_) {
      return null; // Graceful fallback for unsupported/unknown languages
    }
  }
}
