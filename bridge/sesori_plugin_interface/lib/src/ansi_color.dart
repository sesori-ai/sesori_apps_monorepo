import "dart:io";

/// ANSI foreground colors used to highlight terminal output.
enum AnsiColor {
  red("\x1B[31m"),
  yellow("\x1B[33m");

  const AnsiColor(this.code);

  /// The escape sequence that activates this color.
  final String code;
}

/// Wraps terminal text in ANSI color escape sequences.
///
/// Coloring is only applied when [out] is an interactive terminal that supports
/// ANSI escapes. When output is redirected to a file or pipe (or the stream is
/// not a terminal), [colorize] returns the text unchanged so escape sequences
/// never pollute captured logs.
class AnsiColorFormatter {
  AnsiColorFormatter._();

  static const String _reset = "\x1B[0m";

  /// Returns [text] wrapped in [color] when [out] supports ANSI escapes,
  /// otherwise returns [text] unchanged.
  static String colorize({
    required String text,
    required AnsiColor color,
    required Stdout out,
  }) {
    if (!_supportsAnsi(out)) {
      return text;
    }
    return "${color.code}$text$_reset";
  }

  static bool _supportsAnsi(Stdout out) {
    try {
      return out.supportsAnsiEscapes;
    } catch (_) {
      // Fake stdout streams used in tests (and exotic platforms) may not
      // implement the capability probe; treat them as non-terminal.
      return false;
    }
  }
}
