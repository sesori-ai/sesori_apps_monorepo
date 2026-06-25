import "dart:io";

import "terminal_color_validator.dart";

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
/// Whether color is applied is delegated to [TerminalColorValidator] (honoring
/// `FORCE_COLOR`, `NO_COLOR`, `TERM`, and the stream's own ANSI probe). When
/// color is not supported — output redirected to a file or pipe, a non-terminal
/// stream, or an explicit opt-out — [colorize] returns the text unchanged so
/// escape sequences never pollute captured logs.
class AnsiColorFormatter {
  AnsiColorFormatter._();

  static const String _reset = "\x1B[0m";

  /// Returns [text] wrapped in [color] when [TerminalColorValidator] reports
  /// that [out] supports color, otherwise returns [text] unchanged.
  ///
  /// [environment] defaults to the process environment and exists to make the
  /// color opt-in/opt-out deterministically testable.
  static String colorize({
    required String text,
    required AnsiColor color,
    required Stdout out,
    Map<String, String>? environment,
  }) {
    if (!TerminalColorValidator.isSupported(
      out: out,
      environment: environment ?? Platform.environment,
    )) {
      return text;
    }
    return "${color.code}$text$_reset";
  }
}
