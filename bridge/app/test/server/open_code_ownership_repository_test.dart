import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:sesori_bridge/src/server/repositories/open_code_ownership_record.dart';
import 'package:sesori_bridge/src/server/repositories/open_code_ownership_repository.dart';
import 'package:test/test.dart';

void main() {
  group('OpenCodeOwnershipRepository', () {
    late Directory tempDir;
    late RuntimeFileApi runtimeFileApi;
    late OpenCodeOwnershipRepository repository;
    late DateTime fixedNow;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('opencode-ownership-repository-test-');
      runtimeFileApi = RuntimeFileApi(
        runtimeDirectory: p.join(tempDir.path, 'runtime'),
      );
      fixedNow = DateTime.utc(2026, 5, 15, 12, 30, 45);
      repository = OpenCodeOwnershipRepository(
        runtimeFileApi: runtimeFileApi,
        clock: Clock.fixed(fixedNow),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('OpenCode ownership record stores process metadata without password', () async {
      final record = _record(
        ownerSessionId: 'session-a',
        openCodePid: 111,
        port: 50123,
        status: OpenCodeOwnershipStatus.ready,
      );

      await repository.upsert(record: record);

      final String persisted = await File(runtimeFileApi.ownershipFilePath).readAsString();
      expect(persisted, contains('"session-a"'));
      expect(persisted, contains('"openCodePid":111'));
      expect(persisted, contains('"port":50123'));
      expect(persisted, contains('"bridgePid":222'));
      expect(persisted, contains('"openCodeStartMarker":"open-code-start-marker"'));
      expect(persisted, contains('"bridgeStartMarker":"bridge-start-marker"'));
      expect(persisted, contains('"status":"ready"'));
      expect(persisted, isNot(contains('password')));
      expect(persisted, isNot(contains('OPENCODE_SERVER_PASSWORD')));
      expect(persisted, isNot(contains('super-secret-password')));
    });

    test('preserves unrelated records when upserting by owner session id', () async {
      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-a',
          openCodePid: 111,
          port: 50123,
          status: OpenCodeOwnershipStatus.starting,
        ),
      );
      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-b',
          openCodePid: 222,
          port: 50124,
          status: OpenCodeOwnershipStatus.ready,
        ),
      );
      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-a',
          openCodePid: 333,
          port: 50125,
          status: OpenCodeOwnershipStatus.stopping,
        ),
      );

      final records = await repository.readAll();
      expect(records, hasLength(2));

      final sessionA = records.singleWhere((record) => record.ownerSessionId == 'session-a');
      final sessionB = records.singleWhere((record) => record.ownerSessionId == 'session-b');

      expect(sessionA.openCodePid, equals(333));
      expect(sessionA.port, equals(50125));
      expect(sessionA.status, equals(OpenCodeOwnershipStatus.stopping));
      expect(sessionB.openCodePid, equals(222));
      expect(sessionB.port, equals(50124));
      expect(sessionB.status, equals(OpenCodeOwnershipStatus.ready));
    });

    test('deleteByOwnerSessionId removes single record and deletes file when empty', () async {
      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-a',
          openCodePid: 111,
          port: 50123,
          status: OpenCodeOwnershipStatus.ready,
        ),
      );

      await repository.deleteByOwnerSessionId(ownerSessionId: 'session-a');

      expect(await repository.readAll(), isEmpty);
      expect(File(runtimeFileApi.ownershipFilePath).existsSync(), isFalse);
    });

    test('corrupt ownership record is ignored without killing', () async {
      await Directory(p.dirname(runtimeFileApi.ownershipFilePath)).create(recursive: true);
      await File(runtimeFileApi.ownershipFilePath).writeAsString('{ invalid json }');

      final records = await repository.readAll();

      expect(records, isEmpty);
      final invalidFiles = Directory(p.dirname(runtimeFileApi.ownershipFilePath))
          .listSync()
          .whereType<File>()
          .where(
            (file) => p.basename(file.path).startsWith('opencode-processes.invalid.'),
          )
          .toList(growable: false);
      expect(invalidFiles, hasLength(1));
      expect(File(runtimeFileApi.ownershipFilePath).existsSync(), isFalse);
    });

    test('continues fresh when invalid ownership file cannot be renamed', () async {
      if (Platform.isWindows) {
        return;
      }

      await Directory(p.dirname(runtimeFileApi.ownershipFilePath)).create(recursive: true);
      await File(runtimeFileApi.ownershipFilePath).writeAsString('{ invalid json }');

      final chmodResult = await Process.run('chmod', ['500', p.dirname(runtimeFileApi.ownershipFilePath)]);
      addTearDown(() async {
        await Process.run('chmod', ['700', p.dirname(runtimeFileApi.ownershipFilePath)]);
      });
      expect(chmodResult.exitCode, equals(0));

      final records = await repository.readAll();

      expect(records, isEmpty);
      expect(File(runtimeFileApi.ownershipFilePath).existsSync(), isTrue);
    });

    test('unreadable ownership file is treated as invalid and ignored', () async {
      if (Platform.isWindows) {
        return;
      }

      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-a',
          openCodePid: 111,
          port: 50123,
          status: OpenCodeOwnershipStatus.ready,
        ),
      );

      final chmodResult = await Process.run('chmod', ['000', runtimeFileApi.ownershipFilePath]);
      addTearDown(() async {
        await Process.run('chmod', ['600', runtimeFileApi.ownershipFilePath]);
      });
      expect(chmodResult.exitCode, equals(0));

      final records = await repository.readAll();

      expect(records, isEmpty);
    });

    test('deleteByOwnerSessionId surfaces delete failures for last record', () async {
      if (Platform.isWindows) {
        return;
      }

      await repository.upsert(
        record: _record(
          ownerSessionId: 'session-a',
          openCodePid: 111,
          port: 50123,
          status: OpenCodeOwnershipStatus.ready,
        ),
      );

      final chmodResult = await Process.run('chmod', ['500', p.dirname(runtimeFileApi.ownershipFilePath)]);
      addTearDown(() async {
        await Process.run('chmod', ['700', p.dirname(runtimeFileApi.ownershipFilePath)]);
      });
      expect(chmodResult.exitCode, equals(0));

      expect(
        () => repository.deleteByOwnerSessionId(ownerSessionId: 'session-a'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

OpenCodeOwnershipRecord _record({
  required String ownerSessionId,
  required int openCodePid,
  required int port,
  required OpenCodeOwnershipStatus status,
}) {
  return OpenCodeOwnershipRecord(
    ownerSessionId: ownerSessionId,
    openCodePid: openCodePid,
    openCodeStartMarker: 'open-code-start-marker',
    openCodeExecutablePath: '/usr/local/bin/opencode',
    openCodeCommand: 'opencode',
    openCodeArgs: <String>['serve', '--port', '$port'],
    port: port,
    bridgePid: 222,
    bridgeStartMarker: 'bridge-start-marker',
    startedAt: DateTime.utc(2026, 5, 15, 12, 30, 45),
    status: status,
  );
}
