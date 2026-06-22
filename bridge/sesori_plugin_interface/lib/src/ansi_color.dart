import "dart:io";

/// ANSI foreground colors used to highlight terminal output.
enum AnsiColor {
  red("\x1B[31m"),
  yellow("\x1B[33m"),
  blue("\x1B[94m"),
  gray("\x1B[90m");

  const AnsiColor(this.code);

  /// The escape sequence that activates this color.
  final String code;
}

/// Wraps terminal text in ANSI color escape sequences.
///
/// Coloring is only applied when [out] is an interactive terminal that supports
/// ANSI escapes and the `NO_COLOR` environment variable is unset. When output
/// is redirected to a file or pipe (or the stream is not a terminal), or the
/// user has opted out via `NO_COLOR`, [colorize] returns the text unchanged so
/// escape sequences never pollute captured logs.
class AnsiColorFormatter {
  AnsiColorFormatter._();

  static const String _reset = "\x1B[0m";

  /// Returns [text] wrapped in [color] when [out] supports ANSI escapes,
  /// otherwise returns [text] unchanged.
  ///
  /// [environment] defaults to the process environment and exists to make the
  /// `NO_COLOR` opt-out deterministically testable.
  static String colorize({
    required String text,
    required AnsiColor color,
    required Stdout out,
    Map<String, String>? environment,
  }) {
    if (!_supportsAnsi(out: out, environment: environment ?? Platform.environment)) {
      return text;
    }
    return "${color.code}$text$_reset";
  }

  static bool _supportsAnsi({required Stdout out, required Map<String, String> environment}) {
    // Honor the NO_COLOR convention (https://no-color.org/): when the variable
    // is present (regardless of value), disable colorized output even on a
    // capable terminal.
    if (environment.containsKey("NO_COLOR")) {
      return false;
    }
    try {
      return out.supportsAnsiEscapes;
    } catch (_) {
      // Fake stdout streams used in tests (and exotic platforms) may not
      // implement the capability probe; treat them as non-terminal.
      return false;
    }
  }
}
