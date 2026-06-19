import 'dart:io';

import '../../bridge/foundation/legacy_post_update_relaunch.dart';

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
    // A bridge relaunched non-interactively by a legacy auto-updater inherits a
    // real terminal (inheritStdio), so hasTerminal alone would wrongly report it
    // as interactive. Treat that one-version upgrade relaunch as non-interactive
    // so every terminal prompt takes the noninteractive recovery path instead of
    // blocking on stdin or prompting in an unattended successor.
    if (_environment[sesoriPostUpdateRestartEnvVar] == '1') {
      return false;
    }
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
