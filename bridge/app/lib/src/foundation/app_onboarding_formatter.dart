import "dart:io";

import "package:qr/qr.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show TerminalColorValidator, TerminalGlyphValidator;

class AppOnboardingFormatter {
  AppOnboardingFormatter({required Stdout out, required Map<String, String> environment})
    : _out = out,
      _environment = environment;

  static const String appUrl = "https://sesori.com/app/?openStore=true";
  static const int _quietZoneModules = 4;
  static const String _reset = "\x1b[0m";
  static const String _blackForeground = "\x1b[30m";
  static const String _whiteForeground = "\x1b[37m";
  static const String _blackBackground = "\x1b[40m";
  static const String _whiteBackground = "\x1b[47m";
  static const String _upperHalfBlock = "▀";

  final Stdout _out;
  final Map<String, String> _environment;

  String formatDestination() {
    if (!TerminalColorValidator.isSupported(out: _out, environment: _environment) ||
        !TerminalGlyphValidator.isSupported(environment: _environment)) {
      return appUrl;
    }

    final int terminalColumns;
    try {
      terminalColumns = _out.terminalColumns;
    } on Object {
      return appUrl;
    }

    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(appUrl),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    final renderedWidth = image.moduleCount + (_quietZoneModules * 2);
    if (terminalColumns < renderedWidth) {
      return appUrl;
    }

    return "${_renderQr(image: image)}$appUrl";
  }

  String _renderQr({required QrImage image}) {
    final buffer = StringBuffer();
    const start = -_quietZoneModules;
    final end = image.moduleCount + _quietZoneModules;

    for (var row = start; row < end; row += 2) {
      for (var column = start; column < end; column++) {
        final topDark = _isDark(image: image, row: row, column: column);
        final bottomDark = _isDark(image: image, row: row + 1, column: column);
        buffer
          ..write(topDark ? _blackForeground : _whiteForeground)
          ..write(bottomDark ? _blackBackground : _whiteBackground)
          ..write(_upperHalfBlock);
      }
      buffer
        ..write(_reset)
        ..writeln();
    }
    return buffer.toString();
  }

  bool _isDark({required QrImage image, required int row, required int column}) {
    if (row < 0 || column < 0 || row >= image.moduleCount || column >= image.moduleCount) {
      return false;
    }
    return image.isDark(row, column);
  }
}
