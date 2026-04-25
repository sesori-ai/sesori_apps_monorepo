import 'dart:io';

import 'package:sesori_bridge/src/api/linux_default_editor_api.dart';
import 'package:sesori_bridge/src/api/macos_default_editor_api.dart';
import 'package:sesori_bridge/src/api/windows_default_editor_api.dart';
import 'package:test/test.dart';

void main() {
  group('Default editor APIs', () {
    test('MacosDefaultEditorApi runs open for a file', () async {
      final calls = <List<String>>[];
      final api = MacosDefaultEditorApi(
        runProcess: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['open', '/tmp/example.txt']));
    });

    test('LinuxDefaultEditorApi runs xdg-open for a file', () async {
      final calls = <List<String>>[];
      final api = LinuxDefaultEditorApi(
        runProcess: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
      );

      await api.openFile('/tmp/example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['xdg-open', '/tmp/example.txt']));
    });

    test('WindowsDefaultEditorApi runs cmd start for a file', () async {
      final calls = <List<String>>[];
      final api = WindowsDefaultEditorApi(
        runProcess: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
      );

      await api.openFile(r'C:\temp\example.txt');

      expect(calls, hasLength(1));
      expect(calls.single, equals(['cmd', '/c', 'start', r'C:\temp\example.txt']));
    });

    test('default editor APIs swallow command failures', () async {
      final api = MacosDefaultEditorApi(
        runProcess: (_, __) async {
          throw const SocketException('boom');
        },
      );

      await expectLater(api.openFile('/tmp/example.txt'), completes);
    });
  });
}
