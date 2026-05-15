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

  String? readLine({required String message}) {
    _stdout.write(message);
    return _stdin.readLineSync();
  }
}
