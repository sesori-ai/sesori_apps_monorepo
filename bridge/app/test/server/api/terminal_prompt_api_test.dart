import 'dart:io';

import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalPromptApi', () {
    test('interactivity reflects the terminal handles', () {
      final api = TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
        environment: const <String, String>{},
      );

      expect(api.isInteractive, equals(stdin.hasTerminal && stdout.hasTerminal));
    });

    test('legacy post-update relaunch flag forces non-interactive', () {
      final api = TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
        environment: const <String, String>{'SESORI_POST_UPDATE_RESTART': '1'},
      );

      expect(api.isInteractive, isFalse);
    });
  });
}
