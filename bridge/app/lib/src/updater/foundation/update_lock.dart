import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

import '../../bridge/foundation/process_runner.dart';

const Duration _invalidLockGracePeriod = Duration(seconds: 2);

enum LockAcquireResult {
  acquired,
  alreadyLocked,
  permissionDenied,
}

class UpdateLock {
  /// Default age after which a still-"held" `.update.lock` is reaped as stale,
  /// even when the holder PID still appears alive.
  ///
  /// Liveness (PID + process start marker) is the primary, precise check; this
  /// is a last-resort guard against the rare wedge where a crashed holder's PID
  /// is reused by an unrelated long-lived process while the recorded marker was
  /// unavailable. Generous on purpose: a real in-place swap holds the lock for
  /// well under a second, so this never trips a legitimate update.
  static const Duration updateStaleLockMaxAge = Duration(minutes: 15);

  final int _currentPid;
  final ProcessRunner _processRunner;
  final Clock _clock;

  UpdateLock({
    required int currentPid,
    required ProcessRunner processRunner,
    required Clock clock,
  }) : _currentPid = currentPid,
       _processRunner = processRunner,
       _clock = clock;

  Future<T> locked<T>({
    required File lockFile,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(LockAcquireResult result) onLockRejected,
    required bool Function(T value) shouldReleaseLock,
    Duration? staleLockMaxAge,
  }) async {
    final LockAcquireResult lockResult = await _acquireLock(
      lockFile: lockFile,
      staleLockMaxAge: staleLockMaxAge,
    );
    if (lockResult != LockAcquireResult.acquired) {
      return onLockRejected(lockResult);
    }

    late final T value;
    var completed = false;
    try {
      value = await onLockAcquired();
      completed = true;
      return value;
    } finally {
      if (!completed || shouldReleaseLock(value)) {
        await _releaseLock(lockFile: lockFile);
      }
    }
  }

  Future<LockAcquireResult> _acquireLock({
    required File lockFile,
    required Duration? staleLockMaxAge,
  }) async {
    final String ownerJson = jsonEncode(
      _LockOwner(
        pid: _currentPid,
        processMarker: await _currentProcessMarker(),
      ).toJson(),
    );

    try {
      await _createAndWriteLock(lockFile: lockFile, ownerJson: ownerJson);
      return LockAcquireResult.acquired;
    } on PathExistsException {
      final LockAcquireResult staleLockResult = await _removeStaleLockIfNeeded(
        lockFile: lockFile,
        staleLockMaxAge: staleLockMaxAge,
      );
      if (staleLockResult != LockAcquireResult.acquired) {
        return staleLockResult;
      }

      try {
        await _createAndWriteLock(lockFile: lockFile, ownerJson: ownerJson);
        return LockAcquireResult.acquired;
      } on PathExistsException {
        return LockAcquireResult.alreadyLocked;
      } on FileSystemException catch (error) {
        if (_isPermissionDenied(error: error)) {
          return LockAcquireResult.permissionDenied;
        }
        rethrow;
      }
    } on FileSystemException catch (error) {
      if (_isPermissionDenied(error: error)) {
        return LockAcquireResult.permissionDenied;
      }
      rethrow;
    }
  }

  /// Creates [lockFile] exclusively and writes the owner record. If the write
  /// fails after the file was created, the empty lock file is cleaned up before
  /// the error propagates — a transient write failure must not leave a lock file
  /// that blocks other acquirers until the stale-lock grace period reclaims it.
  Future<void> _createAndWriteLock({required File lockFile, required String ownerJson}) async {
    await lockFile.create(exclusive: true);
    try {
      await lockFile.writeAsString(ownerJson, flush: true);
    } on Object {
      await _cleanupUnwrittenLock(lockFile: lockFile);
      rethrow;
    }
  }

  /// Removes the lock file [_createAndWriteLock] just created when its
  /// owner-record write failed — but only while it is still ours.
  ///
  /// "Ours" is an empty, partial, or otherwise unparseable write, or a record
  /// stamped with our own pid. If a slow write let the file age past
  /// [_invalidLockGracePeriod], another acquirer may have reaped it and written
  /// its own owner-stamped lock at the same path; deleting that would break
  /// mutual exclusion, so a record owned by a different pid is left untouched.
  /// Best-effort, but never silent — a cleanup failure is logged.
  Future<void> _cleanupUnwrittenLock({required File lockFile}) async {
    try {
      final _LockOwner? owner = _parseOwner(content: await lockFile.readAsString());
      if (owner == null || owner.pid == _currentPid) {
        await lockFile.delete();
      }
    } on Object catch (error, stackTrace) {
      Log.w('Failed to clean up the lock file after a write failure: $error', error, stackTrace);
    }
  }

  Future<LockAcquireResult> _removeStaleLockIfNeeded({
    required File lockFile,
    required Duration? staleLockMaxAge,
  }) async {
    final String content;
    try {
      content = await lockFile.readAsString();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !lockFile.existsSync()) {
        return LockAcquireResult.acquired;
      }
      if (_isPermissionDenied(error: error)) {
        return LockAcquireResult.permissionDenied;
      }
      rethrow;
    }

    final _LockOwner? owner = _parseOwner(content: content);
    if (owner == null) {
      if (_lockAge(lockFile: lockFile) < _invalidLockGracePeriod) {
        return LockAcquireResult.alreadyLocked;
      }
      return _deleteStaleLock(lockFile: lockFile);
    }

    final String? processMarker = await _readProcessMarker(pidToCheck: owner.pid);
    if (processMarker == null) {
      return _deleteStaleLock(lockFile: lockFile);
    }

    if (owner.processMarker != null && owner.processMarker != processMarker) {
      return _deleteStaleLock(lockFile: lockFile);
    }

    final bool isAlive = await isProcessAlive(pidToCheck: owner.pid);
    if (isAlive) {
      // Liveness says the holder is still running. As a last resort, reap a
      // lock held far longer than any real swap takes (which is sub-second);
      // this only ever clears the rare wedge of a crashed holder whose PID was
      // reused by an unrelated long-lived process.
      if (staleLockMaxAge != null && _lockAge(lockFile: lockFile) > staleLockMaxAge) {
        return _deleteStaleLock(lockFile: lockFile);
      }
      return LockAcquireResult.alreadyLocked;
    }

    return _deleteStaleLock(lockFile: lockFile);
  }

  Duration _lockAge({required File lockFile}) {
    final FileStat stat = lockFile.statSync();
    return _clock.now().difference(stat.modified);
  }

  Future<String?> _currentProcessMarker() {
    return _readProcessMarker(pidToCheck: _currentPid);
  }

  Future<String?> _readProcessMarker({required int pidToCheck}) async {
    if (pidToCheck <= 0) {
      return null;
    }

    if (Platform.isWindows) {
      final ProcessResult result = await _processRunner.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          '(Get-Process -Id $pidToCheck -ErrorAction SilentlyContinue).StartTime.ToUniversalTime().ToString("o")',
        ],
      );
      if (result.exitCode != 0) {
        return null;
      }
      final String marker = result.stdout.toString().trim();
      return marker.isEmpty ? null : marker;
    }

    final ProcessResult result = await _processRunner.run(
      'ps',
      ['-o', 'lstart=', '-p', '$pidToCheck'],
    );
    if (result.exitCode != 0) {
      return null;
    }
    final String marker = result.stdout.toString().trim();
    return marker.isEmpty ? null : marker;
  }

  Future<bool> isProcessAlive({required int pidToCheck}) async {
    if (pidToCheck <= 0) {
      return false;
    }

    if (Platform.isLinux) {
      final Directory procDir = Directory('/proc/$pidToCheck');
      if (procDir.existsSync()) {
        return true;
      }
    }

    if (Platform.isWindows) {
      final ProcessResult result = await _processRunner.run(
        'tasklist',
        ['/FI', 'PID eq $pidToCheck', '/NH'],
      );
      if (result.exitCode != 0) {
        return false;
      }
      final String output = result.stdout.toString();
      return output.contains('$pidToCheck');
    }

    final ProcessResult result = await _processRunner.run(
      'kill',
      ['-0', '$pidToCheck'],
    );
    return result.exitCode == 0;
  }

  Future<void> _releaseLock({required File lockFile}) {
    return _cleanupPath(path: lockFile.path, recursive: false);
  }

  Future<LockAcquireResult> _deleteStaleLock({required File lockFile}) async {
    try {
      await lockFile.delete();
      return LockAcquireResult.acquired;
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !lockFile.existsSync()) {
        return LockAcquireResult.acquired;
      }
      if (_isPermissionDenied(error: error)) {
        return LockAcquireResult.permissionDenied;
      }
      rethrow;
    }
  }

  static bool _isFileMissing({required FileSystemException error}) {
    final int? code = error.osError?.errorCode;
    if (code == 2) {
      return true;
    }

    final String message = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    return message.contains('no such file') || message.contains('cannot find the file');
  }

  static bool _isPermissionDenied({required FileSystemException error}) {
    final int? code = error.osError?.errorCode;
    if (code == 13 || code == 5) {
      return true;
    }
    final String message = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    return message.contains('permission denied') || message.contains('access is denied');
  }

  static _LockOwner? _parseOwner({required String content}) {
    try {
      final Map<String, dynamic> json = jsonDecodeMap(content);
      return _LockOwner.fromJson(json);
    } on Object {
      final int? legacyPid = int.tryParse(content.trim());
      if (legacyPid == null) {
        return null;
      }
      return _LockOwner(pid: legacyPid, processMarker: null);
    }
  }

  static Future<void> _cleanupPath({required String path, required bool recursive}) async {
    try {
      final FileSystemEntityType entityType = FileSystemEntity.typeSync(path);
      switch (entityType) {
        case FileSystemEntityType.file:
          File(path).deleteSync();
        case FileSystemEntityType.directory:
          Directory(path).deleteSync(recursive: recursive);
        case FileSystemEntityType.link:
          Link(path).deleteSync();
        case FileSystemEntityType.unixDomainSock:
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.notFound:
      }
    } on Object {
      stderr.writeln('Warning: updater cleanup failed for $path');
    }
  }
}

final class _LockOwner {
  final int pid;
  final String? processMarker;

  const _LockOwner({required this.pid, required this.processMarker});

  factory _LockOwner.fromJson(Map<String, dynamic> json) {
    return _LockOwner(
      pid: json['pid'] as int,
      processMarker: json['processMarker'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pid': pid,
      'processMarker': processMarker,
    };
  }
}
