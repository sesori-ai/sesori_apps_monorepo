import 'dart:io';

class TerminalPasswordReader {
  TerminalPasswordReader({required Stdin stdin}) : _stdin = stdin;

  final Stdin _stdin;

  String read() {
    final previousEchoMode = _stdin.echoMode;
    try {
      _stdin.echoMode = false;
      final line = _stdin.readLineSync();
      if (line == null) {
        throw Exception('EOF reached while reading password');
      }
      return line;
    } finally {
      _stdin.echoMode = previousEchoMode;
    }
  }
}
