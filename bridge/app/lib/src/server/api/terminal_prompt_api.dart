import 'dart:io';

import '../../bridge/foundation/post_update_restart_flag.dart';

class TerminalPromptApi {
  TerminalPromptApi({
    required Stdin stdin,
    required Stdout stdout,
    required Map<String, String> environment,
  }) : _stdin = stdin,
       _stdout = stdout,
       _environment = environment;

  final Stdin _stdin;
  final Stdout _stdout;
  final Map<String, String> _environment;

  bool get isInteractive {
    if (_environment[sesoriPostUpdateRestartEnvVar] == '1') {
      return false;
    }
    return _stdin.hasTerminal && _stdout.hasTerminal;
  }

  String? readLine({
    required String message,
    bool disableEcho = false, // disable it for passwords
  }) {
    if (_environment[sesoriPostUpdateRestartEnvVar] == '1') {
      return null;
    }

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
