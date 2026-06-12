import 'dart:io';

import 'package:sesori_bridge/src/bridge/foundation/post_update_restart_flag.dart';
import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalPromptApi', () {
    test('post-update restart env flag disables interactivity and readLine without reading', () {
      final api = TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
        environment: const <String, String>{sesoriPostUpdateRestartEnvVar: '1'},
      );

      expect(api.isInteractive, isFalse);
      expect(api.readLine(message: 'should not be written'), isNull);
    });

    test('without post-update restart env flag interactivity uses terminal handles', () {
      final api = TerminalPromptApi(
        stdin: stdin,
        stdout: stdout,
        environment: const <String, String>{},
      );

      expect(api.isInteractive, equals(stdin.hasTerminal && stdout.hasTerminal));
    });
  });
}
