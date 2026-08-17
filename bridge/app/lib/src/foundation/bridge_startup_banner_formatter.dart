import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show TerminalColorValidator, TerminalGlyphValidator;

/// Renders the installer wordmark for interactive standalone bridge starts.
class BridgeStartupBannerFormatter({
  required final Stdout _out,
  required Map<String, String> environment,
}) {
  static const String _reset = "\x1B[0m";
  static const String _banner = "\x1B[0;2m";
  static const String _brand = "\x1B[38;5;39m";
  static const String _bold = "\x1B[1m";
  static const String _dim = "\x1B[2m";

  static const List<String> _unicodeWordmark = [
    " ███████╗███████╗███████╗ ██████╗ ██████╗ ██╗",
    " ██╔════╝██╔════╝██╔════╝██╔═══██╗██╔══██╗██║",
    " ███████╗█████╗  ███████╗██║   ██║██████╔╝██║",
    " ╚════██║██╔══╝  ╚════██║██║   ██║██╔══██╗██║",
    " ███████║███████╗███████║╚██████╔╝██║  ██║██║",
    " ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝",
  ];
  static const List<String> _asciiWordmark = [
    "  ____  _____ ____   ___  ____  ___ ",
    r" / ___|| ____/ ___| / _ \|  _ \|_ _|",
    r" \___ \|  _| \___ \| | | | |_) || | ",
    "  ___) | |___ ___) | |_| |  _ < | | ",
    r" |____/|_____|____/ \___/|_| \_\___|",
  ];

  final bool _color = TerminalColorValidator.isSupported(
    out: _out,
    environment: environment,
  );
  final bool _unicode = TerminalGlyphValidator.isSupported(environment: environment);

  /// Returns the banner, or `null` when stdout is not an interactive terminal.
  String? format({required String version}) {
    if (!_hasTerminal) return null;

    final terminalColumns = _terminalColumns;
    if (terminalColumns == null) return null;

    final compactDetail = " v$version";
    if (terminalColumns < _maxWidth(_asciiWordmark) || terminalColumns < "  BRIDGE$compactDetail".length) {
      return null;
    }
    final wordmark = _unicode && terminalColumns >= _maxWidth(_unicodeWordmark) ? _unicodeWordmark : _asciiWordmark;
    final fullDetail = " v$version  |  AI coding sessions on your phone";
    final detail = terminalColumns >= "  BRIDGE$fullDetail".length ? fullDetail : compactDetail;
    final buffer = StringBuffer()..writeln();
    for (final line in wordmark) {
      buffer.writeln(_paint(code: _banner, text: line));
    }
    buffer
      ..writeln()
      ..write("  ${_paint(code: "$_brand$_bold", text: "BRIDGE")}")
      ..write(_paint(code: _dim, text: detail))
      ..writeln();
    return buffer.toString();
  }

  bool get _hasTerminal {
    try {
      return _out.hasTerminal;
    } on Object {
      return false;
    }
  }

  int? get _terminalColumns {
    try {
      return _out.terminalColumns;
    } on Object {
      return null;
    }
  }

  static int _maxWidth(List<String> lines) => lines.fold(0, (width, line) => line.length > width ? line.length : width);

  String _paint({required String code, required String text}) => _color ? "$code$text$_reset" : text;
}
