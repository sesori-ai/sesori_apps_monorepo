import 'dart:io';

import 'package:sesori_bridge/src/api/linux_default_editor_api.dart';
import 'package:sesori_bridge/src/api/macos_default_editor_api.dart';
import 'package:sesori_bridge/src/api/windows_default_editor_api.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:test/test.dart';

class _FakeProcessRunner implements ProcessRunner {
  final Future<int> Function({
    required String executable,
    required List<String> arguments,
  })
  _handler;

  _FakeProcessRunner({
    required Future<int> Function({
      required String executable,
      required List<String> arguments,
    })
    handler,
  }) : _handler = handler;

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
  group('Default editor APIs', () {
    test('MacosDefaultEditorApi runs open for a file', () async {
      final calls = <List<String>>[];
      final api = MacosDefaultEditorApi(
        processRunner: _FakeProcessRunner(
          handler: ({required executable, required arguments}) async {
            calls.add([executable, ...arguments]);
            return 1;
          },
        ),
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['open', '/tmp/example.txt']));
    });

    test('LinuxDefaultEditorApi runs xdg-open for a file', () async {
      final calls = <List<String>>[];
      final api = LinuxDefaultEditorApi(
        processRunner: _FakeProcessRunner(
          handler: ({required executable, required arguments}) async {
            calls.add([executable, ...arguments]);
            return 1;
          },
        ),
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['xdg-open', '/tmp/example.txt']));
    });

    test('WindowsDefaultEditorApi runs cmd start with empty title for a file', () async {
      final calls = <List<String>>[];
      final api = WindowsDefaultEditorApi(
        processRunner: _FakeProcessRunner(
          handler: ({required executable, required arguments}) async {
            calls.add([executable, ...arguments]);
            return 1;
          },
        ),
      );

      await api.openFile(r'C:\temp\example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['cmd', '/c', 'start', '', r'C:\temp\example.txt']));
    });

    test('default editor APIs propagate command failures', () async {
      final api = MacosDefaultEditorApi(
        processRunner: _FakeProcessRunner(
          handler: ({required executable, required arguments}) async {
            throw const SocketException('boom');
          },
        ),
      );

      await expectLater(
        api.openFile('/tmp/example.txt'),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
