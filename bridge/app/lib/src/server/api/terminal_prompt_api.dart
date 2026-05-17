import 'dart:io';

class TerminalPromptApi {
  TerminalPromptApi({
    required Stdin stdin,
    required Stdout stdout,
  }) : _stdin = stdin,
       _stdout = stdout;

  final Stdin _stdin;
  final Stdout _stdout;

  bool get isInteractive {
    return _stdin.hasTerminal && _stdout.hasTerminal;
  }

  String? readLine({
    required String message,
    bool disableEcho = false, // disable it for passwords
  }) {
    _stdout.write(message);

    if (disableEcho) {
      final previousEchoMode = _stdin.echoMode;
      try {
        _stdin.echoMode = false;
        return _stdin.readLineSync();
      } finally {
        _stdin.echoMode = previousEchoMode;
      }
    } else {
      return _stdin.readLineSync();
    }
  }
}
