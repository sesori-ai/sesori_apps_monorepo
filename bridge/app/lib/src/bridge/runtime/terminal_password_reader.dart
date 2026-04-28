import 'dart:io';

class TerminalPasswordReader {
  TerminalPasswordReader({required Stdin stdin}) : _stdin = stdin;

  final Stdin _stdin;

  String read() {
    final buffer = StringBuffer();
    final previousEchoMode = _stdin.echoMode;
    String? termios;

    try {
      _stdin.echoMode = false;

      if (!Platform.isWindows) {
        try {
          termios = Process.runSync('stty', ['-g']).stdout.toString().trim();
          Process.runSync('stty', ['-icanon', 'min', '1']);
        } catch (_) {}
      }

      _readChars(buffer);
    } finally {
      if (!Platform.isWindows && termios != null) {
        try {
          Process.runSync('stty', [termios]);
        } catch (_) {}
      }
      _stdin.echoMode = previousEchoMode;
    }

    stdout.writeln();
    return buffer.toString();
  }

  void _readChars(StringBuffer buffer) {
    int char;
    while ((char = _stdin.readByteSync()) != 10 && char != 13) {
      if (buffer.isNotEmpty && (char == 127 || char == 8)) {
        stdout.write('\b \b');
        final current = buffer.toString();
        buffer.clear();
        buffer.write(current.substring(0, current.length - 1));
      } else if (char >= 32) {
        buffer.writeCharCode(char);
      }
    }
  }
}
