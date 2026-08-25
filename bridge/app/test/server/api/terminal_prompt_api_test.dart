import 'dart:io';

import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalPromptApi', () {
    test('interactivity reflects the terminal handles', () {
      final api = TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
      );

      expect(api.isInteractive, equals(stdin.hasTerminal && stdout.hasTerminal));
    });
  });
}
