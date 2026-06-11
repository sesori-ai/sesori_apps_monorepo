import 'dart:async';
import 'dart:convert';
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

    group('updateFile', () {
      test('creates the file when absent and returns what was written', () async {
        final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));
        final seenContents = <String?>[];

        final written = await api.updateFile(
          name: 'state.json',
          transform: (current) {
            seenContents.add(current);
            return '{"generation":1}';
          },
        );

        expect(written, '{"generation":1}');
        expect(seenContents, equals(<String?>[null]));
        expect(await api.readFile(name: 'state.json'), '{"generation":1}');
      });

      test('passes current contents to transform and replaces the file', () async {
        final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));
        await api.writeFile(name: 'state.json', contents: '{"generation":1}');

        final written = await api.updateFile(
          name: 'state.json',
          transform: (current) {
            expect(current, '{"generation":1}');
            return '{"generation":2}';
          },
        );

        expect(written, '{"generation":2}');
        expect(await api.readFile(name: 'state.json'), '{"generation":2}');
      });

      test('deletes the file when transform returns null', () async {
        final runtimeDirectory = p.join(tempDir.path, 'runtime');
        final api = RuntimeFileApi(runtimeDirectory: runtimeDirectory);
        await api.writeFile(name: 'state.json', contents: '{}');

        final written = await api.updateFile(name: 'state.json', transform: (current) => null);

        expect(written, isNull);
        expect(File(p.join(runtimeDirectory, 'state.json')).existsSync(), isFalse);
      });

      test('recovers the in-process update queue when transform throws', () async {
        final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));

        await expectLater(
          api.updateFile(name: 'state.json', transform: (current) => throw StateError('boom')),
          throwsA(isA<StateError>()),
        );

        expect(
          await api.updateFile(name: 'state.json', transform: (current) => '{"recovered":true}'),
          '{"recovered":true}',
        );
      });

      test('queues concurrent updates for the same name without losing either', () async {
        final api = RuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'runtime'));
        await api.writeFile(name: 'state.json', contents: '[]');

        final firstEntered = Completer<void>();
        final releaseFirst = Completer<void>();
        final transformCalls = <String>[];

        final first = api.updateFile(
          name: 'state.json',
          transform: (current) async {
            transformCalls.add('first:$current');
            firstEntered.complete();
            await releaseFirst.future;
            return '["first"]';
          },
        );
        await firstEntered.future;

        final second = api.updateFile(
          name: 'state.json',
          transform: (current) {
            transformCalls.add('second:$current');
            return '["first","second"]';
          },
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(transformCalls, equals(<String>['first:[]']));

        releaseFirst.complete();
        expect(await first, '["first"]');
        expect(await second, '["first","second"]');
        expect(transformCalls, equals(<String>['first:[]', 'second:["first"]']));
      });

      test('blocks while another process holds the advisory lock', () async {
        final runtimeDirectory = p.join(tempDir.path, 'runtime');
        await Directory(runtimeDirectory).create(recursive: true);
        final api = RuntimeFileApi(runtimeDirectory: runtimeDirectory);
        final lockPath = p.join(runtimeDirectory, 'state.json${RuntimeFileApi.updateLockSuffix}');

        final holder = await Process.start(
          Platform.resolvedExecutable,
          [_fixturePath('update_lock_holder.dart'), lockPath],
        );
        final holderStdout = holder.stdout.transform(utf8.decoder).transform(const LineSplitter());
        holder.stderr.drain<void>().ignore();
        addTearDown(() {
          holder.kill(ProcessSignal.sigkill);
        });
        expect(await holderStdout.first, 'locked');

        var updateCompleted = false;
        final update = api
            .updateFile(name: 'state.json', transform: (current) => '{"writer":"parent"}')
            .whenComplete(() => updateCompleted = true);

        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(updateCompleted, isFalse, reason: 'updateFile must wait for the cross-process lock');

        holder.stdin.writeln('release');
        await holder.stdin.flush();

        expect(await update, '{"writer":"parent"}');
        expect(await holder.exitCode, 0);
      });
    });
  });
}

String _fixturePath(String name) {
  final candidates = [
    p.join('test', 'server', 'fixtures', name),
    p.join('app', 'test', 'server', 'fixtures', name),
    p.join('bridge', 'app', 'test', 'server', 'fixtures', name),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return p.absolute(candidate);
    }
  }
  throw StateError('Fixture $name not found from ${Directory.current.path}');
}
