import 'dart:io';

class TerminalPromptApi({
  required final Stdin _stdin,
  required final Stdout _stdout,
}) {
  bool get isInteractive => _stdin.hasTerminal && _stdout.hasTerminal;

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
