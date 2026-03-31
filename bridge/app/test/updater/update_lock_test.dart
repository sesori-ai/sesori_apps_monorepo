import 'dart:io';

import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/update_lock.dart';
import 'package:test/test.dart';

class _RecordingProcessRunner implements ProcessRunner {
  final int exitCode;
  String? lastExecutable;
  List<String>? lastArguments;

  _RecordingProcessRunner({required this.exitCode});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastExecutable = executable;
    lastArguments = arguments;
    return ProcessResult(1, exitCode, '', '');
  }
}

void main() {
  group('UpdateLock', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('update-lock-test-');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fresh invalid lockfile rejects via locked callback', () async {
      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('', flush: true);

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      var acquired = false;
      final result = await lock.locked<LockAcquireResult>(
        lockFile: lockFile,
        onLockAcquired: () async {
          acquired = true;
          return LockAcquireResult.acquired;
        },
        onLockRejected: (reason) async => reason,
        shouldReleaseLock: (_) => true,
      );

      expect(acquired, isFalse);
      expect(result, equals(LockAcquireResult.alreadyLocked));
      expect(lockFile.existsSync(), isTrue);
    });

    test('aged invalid lockfile is reclaimed through locked callback', () async {
      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('', flush: true);
      final staleTime = DateTime.now().subtract(const Duration(seconds: 5));
      await lockFile.setLastModified(staleTime);

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      final result = await lock.locked<int>(
        lockFile: lockFile,
        onLockAcquired: () async => 7,
        onLockRejected: (_) async => -1,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(7));
      expect(lockFile.existsSync(), isFalse);
    });

    test('uses injected process runner for liveness checks', () async {
      final runner = _RecordingProcessRunner(exitCode: 1);
      final lock = UpdateLock(
        currentPid: pid,
        processRunner: runner,
      );

      final result = await lock.isProcessAlive(pidToCheck: 999999);

      expect(result, isFalse);
      if (Platform.isWindows) {
        expect(runner.lastExecutable, equals('tasklist'));
      } else if (!Platform.isLinux) {
        expect(runner.lastExecutable, equals('kill'));
      } else {
        expect(runner.lastExecutable, equals('kill'));
      }
    });

    test('locked auto-releases lock after callback completes', () async {
      final lockFile = File('${tempDir.path}/.update.lock');
      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      final result = await lock.locked<int>(
        lockFile: lockFile,
        onLockAcquired: () async {
          expect(lockFile.existsSync(), isTrue);
          return 42;
        },
        onLockRejected: (_) async => -1,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(42));
      expect(lockFile.existsSync(), isFalse);
    });

    test('permission denied while reading existing lock returns permissionDenied', () async {
      if (Platform.isWindows) {
        return;
      }

      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('$pid', flush: true);
      final chmodResult = await Process.run('chmod', ['000', lockFile.path]);
      addTearDown(() async {
        await Process.run('chmod', ['600', lockFile.path]);
      });
      expect(chmodResult.exitCode, equals(0));

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      final result = await lock.locked<LockAcquireResult>(
        lockFile: lockFile,
        onLockAcquired: () async => LockAcquireResult.acquired,
        onLockRejected: (reason) async => reason,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(LockAcquireResult.permissionDenied));
    });

    test('successful operation can keep lock for handoff flows', () async {
      final lockFile = File('${tempDir.path}/.update.lock');
      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      final result = await lock.locked<int>(
        lockFile: lockFile,
        onLockAcquired: () async => 99,
        onLockRejected: (_) async => -1,
        shouldReleaseLock: (_) => false,
      );

      expect(result, equals(99));
      expect(lockFile.existsSync(), isTrue);
    });

    test('permission denied while deleting stale lock returns permissionDenied', () async {
      if (Platform.isWindows) {
        return;
      }

      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('not-a-pid', flush: true);
      final staleTime = DateTime.now().subtract(const Duration(seconds: 5));
      await lockFile.setLastModified(staleTime);
      final chmodResult = await Process.run('chmod', ['500', tempDir.path]);
      addTearDown(() async {
        await Process.run('chmod', ['700', tempDir.path]);
      });
      expect(chmodResult.exitCode, equals(0));

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      final result = await lock.locked<LockAcquireResult>(
        lockFile: lockFile,
        onLockAcquired: () async => LockAcquireResult.acquired,
        onLockRejected: (reason) async => reason,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(LockAcquireResult.permissionDenied));
    });
  });
}
