import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_identity.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/foundation/shutdown_result.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart';
import 'package:test/test.dart';

void main() {
  group('StartupMutexRepository', () {
    late Directory tempDir;
    late RuntimeFileApi runtimeFileApi;
    late _FakeProcessRepository processRepository;
    late StartupMutexRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('startup-mutex-repository-test-');
      runtimeFileApi = RuntimeFileApi(
        runtimeDirectory: p.join(tempDir.path, 'runtime'),
      );
      processRepository = _FakeProcessRepository();
      repository = StartupMutexRepository(
        runtimeFileApi: runtimeFileApi,
        processRepository: processRepository,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('withLock acquires lock for callback and releases it afterward', () async {
      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async {
          final lockContents = await File(runtimeFileApi.startupLockFilePath).readAsString();
          expect(
            jsonDecode(lockContents),
            <String, dynamic>{
              'bridgePid': 123,
              'bridgeStartMarker': 'bridge-start-marker',
            },
          );
          return 42;
        },
        onLockRejected: (_) async => -1,
      );

      expect(result, equals(42));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock rejects contention and leaves existing lock intact', () async {
      final enteredFirstCallback = Completer<void>();
      final releaseFirstCallback = Completer<void>();

      final firstLock = repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async {
          enteredFirstCallback.complete();
          await releaseFirstCallback.future;
          return 1;
        },
        onLockRejected: (_) async => -1,
      );

      await enteredFirstCallback.future;

      processRepository.matchResults[123] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 123,
          startMarker: 'live-bridge',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: 'user',
          platform: 'macos',
          capturedAt: DateTime.utc(2026, 5, 15),
        ),
        kind: ProcessMatchKind.sesoriBridge,
        isCurrentUserProcess: true,
      );

      final secondResult = await repository.withLock<int>(
        bridgePid: 789,
        bridgeStartMarker: 'other-bridge-start-marker',
        onLockAcquired: () async => 2,
        onLockRejected: (result) async {
          expect(result, equals(StartupMutexAcquireResult.alreadyLocked));
          return -1;
        },
      );

      expect(secondResult, equals(-1));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isTrue);

      releaseFirstCallback.complete();
      expect(await firstLock, equals(1));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock steals stale lock when recorded bridge process is dead', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{'bridgePid': 999}),
      );

      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async => 42,
        onLockRejected: (_) async => -1,
      );

      expect(result, equals(42));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock steals stale lock when recorded bridge process is not a bridge', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{'bridgePid': 999}),
      );

      processRepository.matchResults[999] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 999,
          startMarker: 'other-start',
          executablePath: '/usr/local/bin/something-else',
          commandLine: 'something-else',
          ownerUser: 'user',
          platform: 'macos',
          capturedAt: DateTime.utc(2026, 5, 15),
        ),
        kind: ProcessMatchKind.unknown,
        isCurrentUserProcess: true,
      );

      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async => 42,
        onLockRejected: (_) async => -1,
      );

      expect(result, equals(42));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock steals stale lock when lock file is corrupt', () async {
      await runtimeFileApi.acquireStartupLock(contents: 'not-json');

      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async => 42,
        onLockRejected: (_) async => -1,
      );

      expect(result, equals(42));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock releases lock when callback throws', () async {
      expect(
        () => repository.withLock<void>(
          bridgePid: 123,
          bridgeStartMarker: 'bridge-start-marker',
          onLockAcquired: () async {
            throw StateError('boom');
          },
          onLockRejected: (_) async {},
        ),
        throwsA(isA<StateError>()),
      );

      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });

    test('withLock rejects when lock held by live bridge on another PID', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{'bridgePid': 456}),
      );

      processRepository.matchResults[456] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 456,
          startMarker: 'live-bridge',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: 'user',
          platform: 'macos',
          capturedAt: DateTime.utc(2026, 5, 15),
        ),
        kind: ProcessMatchKind.sesoriBridge,
        isCurrentUserProcess: true,
      );

      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async => 42,
        onLockRejected: (result) async {
          expect(result, equals(StartupMutexAcquireResult.alreadyLocked));
          return -1;
        },
      );

      expect(result, equals(-1));
    });
  });
}

class _FakeProcessRepository implements ProcessRepository {
  final Map<int, ProcessMatch?> matchResults = <int, ProcessMatch?>{};

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    return null;
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    return matchResults[pid];
  }

  @override
  Future<List<ProcessIdentity>> listProcessIdentities({required int? excludePid}) async {
    return const <ProcessIdentity>[];
  }

  @override
  Future<List<ProcessMatch>> listProcesses({required int? excludePid}) async {
    return const <ProcessMatch>[];
  }

  @override
  Future<ShutdownResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<ShutdownResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }
}
