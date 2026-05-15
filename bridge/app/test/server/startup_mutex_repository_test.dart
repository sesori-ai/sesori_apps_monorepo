import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart';
import 'package:test/test.dart';

void main() {
  group('StartupMutexRepository', () {
    late Directory tempDir;
    late RuntimeFileApi runtimeFileApi;
    late StartupMutexRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('startup-mutex-repository-test-');
      runtimeFileApi = RuntimeFileApi(
        runtimeDirectory: p.join(tempDir.path, 'runtime'),
      );
      repository = StartupMutexRepository(runtimeFileApi: runtimeFileApi);
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

      final secondResult = await repository.withLock<int>(
        bridgePid: 456,
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

    test('concurrent withLock calls let exactly one callback proceed', () async {
      final acquiredCallback = Completer<void>();
      final releaseWinner = Completer<void>();
      var acquiredCount = 0;
      var rejectedCount = 0;

      final firstFuture = repository.withLock<int>(
        bridgePid: 123,
        bridgeStartMarker: 'bridge-start-marker',
        onLockAcquired: () async {
          acquiredCount += 1;
          if (!acquiredCallback.isCompleted) {
            acquiredCallback.complete();
          }
          if (!releaseWinner.isCompleted) {
            await releaseWinner.future;
          }
          return 1;
        },
        onLockRejected: (_) async {
          rejectedCount += 1;
          return -1;
        },
      );

      final secondFuture = repository.withLock<int>(
        bridgePid: 456,
        bridgeStartMarker: 'other-bridge-start-marker',
        onLockAcquired: () async {
          acquiredCount += 1;
          if (!acquiredCallback.isCompleted) {
            acquiredCallback.complete();
          }
          if (!releaseWinner.isCompleted) {
            await releaseWinner.future;
          }
          return 2;
        },
        onLockRejected: (_) async {
          rejectedCount += 1;
          return -2;
        },
      );

      await acquiredCallback.future;
      expect(acquiredCount, equals(1));
      expect(rejectedCount, equals(1));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isTrue);

      releaseWinner.complete();
      final results = await Future.wait<int>(<Future<int>>[firstFuture, secondFuture]);
      expect(results.where((result) => result > 0), hasLength(1));
      expect(results.where((result) => result < 0), hasLength(1));
      expect(File(runtimeFileApi.startupLockFilePath).existsSync(), isFalse);
    });
  });
}
