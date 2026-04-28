import 'dart:io';

class TerminalPasswordReader {
  TerminalPasswordReader({required Stdin stdin}) : _stdin = stdin;

  final Stdin _stdin;

  String read() {
    final buffer = StringBuffer();

    if (Platform.isWindows) {
      try {
        Process.runSync('stty', ['-icanon', 'min', '1']);
        Process.runSync('stty', ['-echo']);
      } catch (_) {}
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
      try {
        Process.runSync('stty', ['icanon']);
        Process.runSync('stty', ['echo']);
      } catch (_) {}
      stdout.writeln();
      return buffer.toString();
    } else {
      final termios = Process.runSync('stty', ['-g']);
      Process.runSync('stty', ['-echo']);
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
      try {
        Process.runSync('stty', [termios.stdout.toString().trim()]);
      } catch (_) {}
      stdout.writeln();
      return buffer.toString();
    }
  }
}
