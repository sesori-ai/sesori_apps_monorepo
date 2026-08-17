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

    final wordmark = _unicode ? _unicodeWordmark : _asciiWordmark;
    final buffer = StringBuffer()..writeln();
    for (final line in wordmark) {
      buffer.writeln(_paint(code: _banner, text: line));
    }
    buffer
      ..writeln()
      ..write("  ${_paint(code: "$_brand$_bold", text: "BRIDGE")} ")
      ..write(_paint(code: _dim, text: "v$version  |  AI coding sessions on your phone"))
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

  String _paint({required String code, required String text}) => _color ? "$code$text$_reset" : text;
}
