import 'dart:io';

import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/foundation/process_runner.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;
import 'package:test/test.dart';

class _FakeProcessRunner({
  required final Future<int> Function({required String executable, required List<String> arguments}) _handler,
}) implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) => _handler(executable: executable, arguments: arguments);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) => throw StateError('Default editor launchers must use startDetached');
}

void main() {
  for (final testCase in <({PlatformOs platform, List<String> command})>[
    (platform: PlatformOs.macos, command: ['open', '/tmp/example.txt']),
    (platform: PlatformOs.linux, command: ['xdg-open', '/tmp/example.txt']),
    (platform: PlatformOs.windows, command: ['cmd', '/c', 'start', '', '/tmp/example.txt']),
  ]) {
    test('${testCase.platform.name} opens file with platform command', () async {
      final calls = <List<String>>[];
      final api = DefaultEditorApi.forPlatform(
        platform: testCase.platform,
        processRunner: _FakeProcessRunner(
          handler: ({required executable, required arguments}) async {
            calls.add([executable, ...arguments]);
            return 1;
          },
        ),
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, [testCase.command]);
    });
  }

  test('propagates command failures', () async {
    final api = DefaultEditorApi.forPlatform(
      platform: PlatformOs.macos,
      processRunner: _FakeProcessRunner(
        handler: ({required executable, required arguments}) async => throw const SocketException('boom'),
      ),
    );

    await expectLater(api.openFile('/tmp/example.txt'), throwsA(isA<SocketException>()));
  });
}
