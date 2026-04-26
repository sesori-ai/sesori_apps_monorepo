import 'dart:io';

import 'package:sesori_bridge/src/api/linux_default_editor_api.dart';
import 'package:sesori_bridge/src/api/macos_default_editor_api.dart';
import 'package:sesori_bridge/src/api/windows_default_editor_api.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:test/test.dart';

class _FakeProcessRunner implements ProcessRunner {
  final Future<ProcessResult> Function(String, List<String>) _handler;

  _FakeProcessRunner(this._handler);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) => _handler(executable, arguments);
}

void main() {
  group('Default editor APIs', () {
    test('MacosDefaultEditorApi runs open for a file', () async {
      final calls = <List<String>>[];
      final api = MacosDefaultEditorApi(
        processRunner: _FakeProcessRunner((executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        }),
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['open', '/tmp/example.txt']));
    });

    test('LinuxDefaultEditorApi runs xdg-open for a file', () async {
      final calls = <List<String>>[];
      final api = LinuxDefaultEditorApi(
        processRunner: _FakeProcessRunner((executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        }),
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['xdg-open', '/tmp/example.txt']));
    });

    test('WindowsDefaultEditorApi runs cmd start with empty title for a file', () async {
      final calls = <List<String>>[];
      final api = WindowsDefaultEditorApi(
        processRunner: _FakeProcessRunner((executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        }),
      );

      await api.openFile(r'C:\temp\example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['cmd', '/c', 'start', '', r'C:\temp\example.txt']));
    });

    test('default editor APIs propagate command failures', () async {
      final api = MacosDefaultEditorApi(
        processRunner: _FakeProcessRunner((_, __) async {
          throw const SocketException('boom');
        }),
      );

      await expectLater(
        api.openFile('/tmp/example.txt'),
        throwsA(isA<SocketException>()),
      );
    });

    test('default editor APIs throw on non-zero exit code', () async {
      final api = LinuxDefaultEditorApi(
        processRunner: _FakeProcessRunner((_, __) async {
          return ProcessResult(0, 1, '', 'no such file');
        }),
      );

      await expectLater(
        api.openFile('/tmp/example.txt'),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
