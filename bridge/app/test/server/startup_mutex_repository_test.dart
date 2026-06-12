import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
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
          startMarker: 'bridge-start-marker',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: ProcessUser.fromRawUser("user"),
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
          expect(result.lock?.bridgePid, equals(123));
          expect(result.lock?.bridgeStartMarker, equals('bridge-start-marker'));
          expect(result.holderMatch?.identity.pid, equals(123));
          expect(result.lockFilePath, equals(runtimeFileApi.startupLockFilePath));
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

    test('withLock clears stale lock recording caller pid and retry succeeds', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{
          'bridgePid': 123,
          'bridgeStartMarker': null,
        }),
      );

      processRepository.matchResults[123] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 123,
          startMarker: null,
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: ProcessUser.fromRawUser('user'),
          platform: 'windows',
          capturedAt: DateTime.utc(2026, 5, 15),
        ),
        kind: ProcessMatchKind.sesoriBridge,
        isCurrentUserProcess: true,
      );

      final result = await repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: null,
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
          ownerUser: ProcessUser.fromRawUser("user  "),
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
      await expectLater(
        repository.withLock<void>(
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

    test('withLock rejects when lock held by live bridge with matching start marker', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{
          'bridgePid': 456,
          'bridgeStartMarker': 'live-bridge',
        }),
      );

      processRepository.matchResults[456] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 456,
          startMarker: 'live-bridge',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: ProcessUser.fromRawUser(" USER"),
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
          expect(result.lock?.bridgePid, equals(456));
          expect(result.holderMatch?.identity.pid, equals(456));
          expect(result.lockFilePath, equals(runtimeFileApi.startupLockFilePath));
          return -1;
        },
      );

      expect(result, equals(-1));
    });

    test('withLock rejection carries nulls when vanished lock race cannot identify holder', () async {
      final fakeRuntimeFileApi = _RacingRuntimeFileApi(runtimeDirectory: p.join(tempDir.path, 'racing-runtime'));
      final racingRepository = StartupMutexRepository(
        runtimeFileApi: fakeRuntimeFileApi,
        processRepository: processRepository,
      );

      final result = await racingRepository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async => 42,
        onLockRejected: (rejection) async {
          expect(rejection.lock, isNull);
          expect(rejection.holderMatch, isNull);
          expect(rejection.lockFilePath, equals(fakeRuntimeFileApi.startupLockFilePath));
          return -1;
        },
      );

      expect(result, equals(-1));
    });

    test('withLock steals stale lock when PID was recycled to a different bridge', () async {
      await runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(<String, dynamic>{
          'bridgePid': 456,
          'bridgeStartMarker': 'original-start',
        }),
      );

      processRepository.matchResults[456] = ProcessMatch(
        identity: ProcessIdentity(
          pid: 456,
          startMarker: 'recycled-start',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: 'sesori-bridge',
          ownerUser: ProcessUser.fromRawUser(" USer"),
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
        onLockRejected: (_) async => -1,
      );

      expect(result, equals(42));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
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
  Future<SignalResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }
}

class _RacingRuntimeFileApi extends RuntimeFileApi {
  _RacingRuntimeFileApi({required super.runtimeDirectory});

  @override
  Future<bool> acquireStartupLock({required String contents}) async {
    return false;
  }

  @override
  Future<String?> readStartupLock() async {
    return null;
  }
}
