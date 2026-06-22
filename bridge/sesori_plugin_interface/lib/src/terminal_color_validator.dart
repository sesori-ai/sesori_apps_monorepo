import "dart:io";

/// Decides whether ANSI color escapes should be written to [out].
///
/// The rules mirror the Sesori installer scripts (see `install.sh`) so the CLI,
/// the loggers, and the installers all agree on when color is safe:
///
/// 1. `FORCE_COLOR` (present with any value, even empty) forces color on — an
///    explicit opt-in that overrides every other signal, including a
///    non-terminal [out]. This is the only way ANSI escapes reach a redirected
///    stream.
/// 2. `NO_COLOR` (present with any value) forces color off
///    (https://no-color.org/).
/// 3. `TERM=dumb` forces color off.
/// 4. Otherwise the stream's own [Stdout.supportsAnsiEscapes] probe decides
///    (false for pipes/files, and for fake/exotic streams whose probe throws).
///
/// Unlike the shell installer, an empty/unset `TERM` does NOT force color off:
/// Dart's `supportsAnsiEscapes` is a more reliable capability signal than the
/// mere presence of `TERM`, and forcing off there would regress color on real
/// terminals that do not export `TERM`.
class TerminalColorValidator {
  TerminalColorValidator._();

  /// Whether color may be emitted to [out] under [environment].
  static bool isSupported({
    required Stdout out,
    required Map<String, String> environment,
  }) {
    if (environment.containsKey("FORCE_COLOR")) {
      return true;
    }
    if (environment.containsKey("NO_COLOR")) {
      return false;
    }
    if (environment["TERM"] == "dumb") {
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
