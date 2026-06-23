import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:test/test.dart';

class _RecordingProcessRunner implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final int exitCode;
  final String stdout;
  String? lastExecutable;
  List<String>? lastArguments;

  _RecordingProcessRunner({required this.exitCode, this.stdout = ''});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastExecutable = executable;
    lastArguments = arguments;
    return ProcessResult(1, exitCode, stdout, '');
  }
}

/// A lock file whose exclusive `create` succeeds but whose `writeAsString`
/// fails, so the owner record is never written. Records whether `delete` was
/// called, to verify the empty lock file is cleaned up on a write failure.
class _WriteFailingFile implements File {
  _WriteFailingFile({this.contentAfterFailedWrite = ''});

  /// What `readAsString` returns during cleanup. Empty means the empty file we
  /// created is still there; non-empty simulates another acquirer having reaped
  /// it and written its own owner-stamped lock at the same path.
  final String contentAfterFailedWrite;
  bool deleted = false;

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async => this;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    throw const FileSystemException('simulated write failure');
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => contentAfterFailedWrite;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    deleted = true;
    return this;
  }

  @override
  String get path => '/tmp/.update.lock';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
        clock: const Clock(),
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
        clock: const Clock(),
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
        clock: const Clock(),
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
        clock: const Clock(),
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
        clock: const Clock(),
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
        clock: const Clock(),
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

    test('stale lock is reclaimed when the pid has been reused by another process marker', () async {
      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString(
        '{"pid":999999,"processMarker":"old-process-marker"}',
        flush: true,
      );

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(
          exitCode: 0,
          stdout: 'new-process-marker\n',
        ),
        clock: const Clock(),
      );

      final result = await lock.locked<int>(
        lockFile: lockFile,
        onLockAcquired: () async => 1,
        onLockRejected: (_) async => -1,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(1));
      expect(lockFile.existsSync(), isFalse);
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
        clock: const Clock(),
      );

      final result = await lock.locked<LockAcquireResult>(
        lockFile: lockFile,
        onLockAcquired: () async => LockAcquireResult.acquired,
        onLockRejected: (reason) async => reason,
        shouldReleaseLock: (_) => true,
      );

      expect(result, equals(LockAcquireResult.permissionDenied));
    });

    test('a held lock older than staleLockMaxAge is reaped as a last resort', () async {
      if (Platform.isWindows) {
        return;
      }

      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('{"pid":999999,"processMarker":"marker"}', flush: true);
      // Make the lock look far older than any real swap would take.
      await lockFile.setLastModified(DateTime.now().subtract(const Duration(minutes: 20)));

      final lock = UpdateLock(
        currentPid: pid,
        // exitCode 0 makes the recorded-marker read match and the liveness
        // (kill -0) probe report the holder as alive, so only the age guard can
        // reclaim the lock.
        processRunner: _RecordingProcessRunner(exitCode: 0, stdout: 'marker\n'),
        clock: Clock.fixed(DateTime.now()),
      );

      final result = await lock.locked<int>(
        lockFile: lockFile,
        onLockAcquired: () async => 1,
        onLockRejected: (_) async => -1,
        shouldReleaseLock: (_) => true,
        staleLockMaxAge: const Duration(minutes: 15),
      );

      expect(result, equals(1));
      expect(lockFile.existsSync(), isFalse);
    });

    test('a held lock within staleLockMaxAge stays locked', () async {
      if (Platform.isWindows) {
        return;
      }

      final lockFile = File('${tempDir.path}/.update.lock');
      await lockFile.writeAsString('{"pid":999999,"processMarker":"marker"}', flush: true);

      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 0, stdout: 'marker\n'),
        clock: Clock.fixed(DateTime.now()),
      );

      final result = await lock.locked<LockAcquireResult>(
        lockFile: lockFile,
        onLockAcquired: () async => LockAcquireResult.acquired,
        onLockRejected: (reason) async => reason,
        shouldReleaseLock: (_) => true,
        staleLockMaxAge: const Duration(minutes: 15),
      );

      expect(result, equals(LockAcquireResult.alreadyLocked));
      expect(lockFile.existsSync(), isTrue);
    });

    test('a write failure after create deletes the empty lock file', () async {
      final lockFile = _WriteFailingFile();
      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
        clock: const Clock(),
      );

      await expectLater(
        lock.locked<int>(
          lockFile: lockFile,
          onLockAcquired: () async => 1,
          onLockRejected: (_) async => -1,
          shouldReleaseLock: (_) => true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      // The empty lock file is removed rather than left to block other
      // acquirers until the grace period reclaims it.
      expect(lockFile.deleted, isTrue);
    });

    test('a write failure does not delete a lock another process recreated', () async {
      // Simulate a slow write: by the time cleanup runs, another acquirer has
      // reaped the empty lock and written its own owner-stamped lock at the
      // same path. We must not delete that one.
      final lockFile = _WriteFailingFile(contentAfterFailedWrite: '{"pid":4242,"processMarker":"other"}');
      final lock = UpdateLock(
        currentPid: pid,
        processRunner: _RecordingProcessRunner(exitCode: 1),
        clock: const Clock(),
      );

      await expectLater(
        lock.locked<int>(
          lockFile: lockFile,
          onLockAcquired: () async => 1,
          onLockRejected: (_) async => -1,
          shouldReleaseLock: (_) => true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(lockFile.deleted, isFalse);
    });
  });
}
