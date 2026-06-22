/// Decides whether unicode glyphs (rather than ASCII fallbacks) are safe to
/// emit to the terminal.
///
/// The rules mirror the Sesori installer scripts (see `install.sh`):
///
/// 1. `TERM=dumb` forces ASCII.
/// 2. Otherwise a UTF-8 locale enables unicode glyphs. The locale is read from
///    `LC_ALL`, then `LC_CTYPE`, then `LANG` (first set wins) and matched
///    case-insensitively against `utf-8`/`utf8`.
/// 3. Anything else (including an unset locale) falls back to ASCII.
///
/// Glyph support is independent of the output stream, so [isSupported] takes
/// only the [environment]; callers pair the result with their own glyph and
/// ASCII-fallback sets.
class TerminalGlyphValidator {
  TerminalGlyphValidator._();

  /// Whether unicode glyphs may be emitted under [environment].
  static bool isSupported({required Map<String, String> environment}) {
    if (environment["TERM"] == "dumb") {
      return false;
    }
    final locale =
        (environment["LC_ALL"] ?? environment["LC_CTYPE"] ?? environment["LANG"] ?? "").toLowerCase();
    return locale.contains("utf-8") || locale.contains("utf8");
  }
}
