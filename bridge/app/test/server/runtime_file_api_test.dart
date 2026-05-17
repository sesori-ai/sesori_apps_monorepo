import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeFileApi', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('runtime-file-api-test-');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes, reads, and deletes ownership state atomically', () async {
      final runtimeDirectory = p.join(tempDir.path, 'runtime');
      final api = RuntimeFileApi(runtimeDirectory: runtimeDirectory);

      await api.writeOwnershipFile(contents: '{"session-a":{"ownerSessionId":"session-a"}}');

      expect(Directory(runtimeDirectory).existsSync(), isTrue);
      expect(await api.readOwnershipFile(), '{"session-a":{"ownerSessionId":"session-a"}}');

      await api.deleteOwnershipFile();

      expect(await api.readOwnershipFile(), isNull);
      expect(File(api.ownershipFilePath).existsSync(), isFalse);
    });

    test('deleteOwnershipFile ignores missing files', () async {
      final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));

      await api.deleteOwnershipFile();

      expect(File(api.ownershipFilePath).existsSync(), isFalse);
    });

    test('writeOwnershipFile creates missing runtime directory', () async {
      final runtimeDirectory = p.join(tempDir.path, 'nested', 'runtime');
      final api = RuntimeFileApi(runtimeDirectory: runtimeDirectory);

      await api.writeOwnershipFile(contents: '{}');

      expect(Directory(runtimeDirectory).existsSync(), isTrue);
      expect(File(api.ownershipFilePath).existsSync(), isTrue);
    });

    test('writeOwnershipFile overwrites existing ownership file via temp rename', () async {
      final runtimeDirectory = p.join(tempDir.path, 'runtime');
      final api = RuntimeFileApi(runtimeDirectory: runtimeDirectory);

      await api.writeOwnershipFile(contents: '{"session-a":{"ownerSessionId":"session-a"}}');
      await api.writeOwnershipFile(contents: '{"session-b":{"ownerSessionId":"session-b"}}');

      expect(
        await File(api.ownershipFilePath).readAsString(),
        '{"session-b":{"ownerSessionId":"session-b"}}',
      );
      expect(File('${api.ownershipFilePath}.tmp').existsSync(), isFalse);
    });

    test('writeOwnershipFile propagates filesystem failures', () async {
      final blockingFile = File(p.join(tempDir.path, 'not-a-directory'));
      await blockingFile.writeAsString('blocker');
      final api = RuntimeFileApi(
        runtimeDirectory: p.join(blockingFile.path, 'runtime'),
      );

      expect(
        () => api.writeOwnershipFile(contents: '{}'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('renameOwnershipFile moves invalid file aside', () async {
      final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));
      await api.writeOwnershipFile(contents: '{ invalid json }');

      await api.renameOwnershipFile(
        fileName: 'opencode-processes.invalid.2026-05-15T10-00-00Z.json',
      );

      expect(File(api.ownershipFilePath).existsSync(), isFalse);
      expect(
        File(
          p.join(
            p.dirname(api.ownershipFilePath),
            'opencode-processes.invalid.2026-05-15T10-00-00Z.json',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('deleteOwnershipFile surfaces delete failures', () async {
      if (Platform.isWindows) {
        return;
      }

      final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));
      await api.writeOwnershipFile(contents: '{}');

      final chmodResult = await Process.run('chmod', ['500', p.dirname(api.ownershipFilePath)]);
      addTearDown(() async {
        await Process.run('chmod', ['700', p.dirname(api.ownershipFilePath)]);
      });
      expect(chmodResult.exitCode, equals(0));

      expect(
        api.deleteOwnershipFile,
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
