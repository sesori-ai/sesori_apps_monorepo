import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart'
    show TerminalColorValidator, TerminalGlyphValidator;

/// A single rendered output line and where it belongs. [isError] lines go to
/// stderr; the rest go to stdout. The [text] is already styled (color/glyphs
/// applied or stripped) for its destination, so consumers only write it.
class RenderedLine {
  final bool isError;
  final String text;

  const RenderedLine({required this.isError, required this.text});
}

/// Formats text and download state into the bridge updater's branded terminal
/// vocabulary: the palette, glyph set, and capability-gated painting primitives
/// shared by every updater output surface (the `sesori-bridge update` command,
/// the background/startup status lines, and the download progress bar). Kept
/// visually consistent with the installer scripts (`install.sh` /
/// `install.ps1` / `lib/ui.js`).
///
/// An instance is bound to ONE output stream's capabilities: whether color and
/// unicode glyphs are safe there. Build one per stream with [forStream] (which
/// resolves those via [TerminalColorValidator] / [TerminalGlyphValidator]) and
/// inject it — the formatter retains only the two resolved booleans, never the
/// raw [Stdout] or environment. Every builder returns a styled string; the
/// formatter performs no IO.
class UpdateOutputFormatter {
  const UpdateOutputFormatter({required bool color, required bool unicode})
    : _color = color,
      _unicode = unicode;

  /// Resolves color/glyph support for [out] under [environment] and captures
  /// only the two resulting booleans.
  factory UpdateOutputFormatter.forStream({
    required Stdout out,
    required Map<String, String> environment,
  }) {
    return UpdateOutputFormatter(
      color: TerminalColorValidator.isSupported(out: out, environment: environment),
      unicode: TerminalGlyphValidator.isSupported(environment: environment),
    );
  }

  final bool _color;
  final bool _unicode;

  // ┌─ PALETTE ────────────────────────────────────────────────────────────────
  // │ 256-color codes matching the installer palette: brand blue #1472FF ≈ 39.
  // └────────────────────────────────────────────────────────────────────────────
  static const String _reset = '\x1B[0m';
  static const String _brand = '\x1B[38;5;39m';
  static const String _green = '\x1B[38;5;42m';
  static const String _yellow = '\x1B[38;5;214m';
  static const String _red = '\x1B[38;5;203m';
  static const String _dim = '\x1B[2m';
  static const String _bold = '\x1B[1m';

  /// Whether ANSI color is emitted to this formatter's stream. Callers that draw
  /// their own animated output (e.g. the progress bar) gate on this.
  bool get color => _color;

  /// A green success line: `✓ <text>` (`[OK]` without unicode).
  String success(String text) => '${_glyph(_green, '\u2713', '[OK]')} $text';

  /// A yellow warning line: `⚠ <text>` (`!` without unicode).
  String warn(String text) => '${_glyph(_yellow, '\u26a0', '!')} $text';

  /// A red error line: `✗ <text>` (`x` without unicode).
  String error(String text) => '${_glyph(_red, '\u2717', 'x')} $text';

  /// A brand-blue note line: `➜ <text>` (`>` without unicode).
  String note(String text) => '${_glyph(_brand, '\u279c', '>')} $text';

  /// Muted secondary text.
  String dim(String text) => _paint(_dim, text);

  /// A highlighted, runnable command (brand blue + bold).
  String command(String text) => _paint('$_brand$_bold', text);

  /// The arrow separator between two versions: `→` (`->` without unicode).
  String get arrow => _unicode ? '\u2192' : '->';

  /// A determinate progress bar of [totalCells] wide with [filledCells] filled:
  /// brand-blue `■` filled + dim `･` remainder (`#`/`.` without unicode).
  String progressBar({required int filledCells, required int totalCells}) {
    final int filled = filledCells.clamp(0, totalCells);
    final String full = (_unicode ? '\u25a0' : '#') * filled;
    final String empty = (_unicode ? '\uff65' : '.') * (totalCells - filled);
    if (!_color) {
      return '$full$empty';
    }
    return '$_brand$full$_dim$empty$_reset';
  }

  String _glyph(String code, String unicode, String ascii) => _paint(code, _unicode ? unicode : ascii);

  String _paint(String code, String text) => _color ? '$code$text$_reset' : text;
}
