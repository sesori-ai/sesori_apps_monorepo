import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Raw file persistence inside [runtimeDirectory].
///
/// Keep a single instance per directory per process: [updateFile]'s mutual
/// exclusion combines an OS advisory lock (cross-process) with an in-process
/// per-name queue, and the in-process half lives on this instance. POSIX
/// advisory locks neither exclude lockers within one process nor survive
/// another file descriptor to the lock file being closed, so a second
/// instance over the same directory would silently break the guarantee.
class RuntimeFileApi {
  final String runtimeDirectory;

  RuntimeFileApi({required this.runtimeDirectory});

  static const String _ownershipFileName = 'opencode-processes.json';

  /// Suffix of the sidecar files [updateFile] takes its advisory lock on.
  ///
  /// Sidecars are created next to the data file and deliberately never
  /// deleted: the data file itself is replaced by rename on every write, so a
  /// lock taken on it could outlive the inode it guards, and deleting the
  /// sidecar would reopen the same race.
  static const String updateLockSuffix = '.update-lock';

  final Map<String, Future<void>> _updateChains = <String, Future<void>>{};

  String get ownershipFilePath => p.join(runtimeDirectory, _ownershipFileName);

  String get startupLockFilePath => p.join(runtimeDirectory, 'bridge-startup.lock');

  Future<String?> readOwnershipFile() => readFile(name: _ownershipFileName);

  Future<void> writeOwnershipFile({required String contents}) =>
      writeFile(name: _ownershipFileName, contents: contents);

  Future<void> deleteOwnershipFile() => deleteFile(name: _ownershipFileName);

  Future<void> renameOwnershipFile({required String fileName}) =>
      renameFile(fromName: _ownershipFileName, toName: fileName);

  Future<String?> readFile({required String name}) async {
    final file = File(p.join(runtimeDirectory, name));
    if (!file.existsSync()) {
      return null;
    }

    try {
      return await file.readAsString();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !file.existsSync()) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> writeFile({required String name, required String contents}) async {
    await _ensureRuntimeDirectory();

    final targetPath = p.join(runtimeDirectory, name);
    final targetFile = File(targetPath);
    final tmpFile = File('$targetPath.tmp');
    await tmpFile.writeAsString(contents, flush: true);

    try {
      await tmpFile.rename(targetFile.path);
    } on FileSystemException {
      // On Windows rename over an existing file fails. Delete target and retry.
      if (targetFile.existsSync()) {
        await targetFile.delete();
        await tmpFile.rename(targetFile.path);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteFile({required String name}) async {
    final file = File(p.join(runtimeDirectory, name));
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !file.existsSync()) {
        return;
      }
      rethrow;
    }
  }

  Future<void> renameFile({required String fromName, required String toName}) async {
    final sourceFile = File(p.join(runtimeDirectory, fromName));
    if (!sourceFile.existsSync()) {
      return;
    }

    final targetFile = File(p.join(runtimeDirectory, toName));
    await sourceFile.rename(targetFile.path);
  }

  /// Reads [name], applies [transform], and writes the result back atomically
  /// while holding an exclusive OS advisory lock on the file's sidecar, so
  /// mutators in other bridge processes cannot drop each other's changes.
  ///
  /// [transform] receives the current contents (`null` when the file does not
  /// exist) and returns the new contents; returning `null` deletes the file.
  /// Returns what was written (or `null` when deleted). [transform] must not
  /// call [updateFile] for the same [name] — calls for one name are queued on
  /// this instance and a reentrant call would deadlock behind itself.
  Future<String?> updateFile({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) {
    final previous = _updateChains[name] ?? Future<void>.value();
    final completer = Completer<void>();
    _updateChains[name] = completer.future;
    return previous.then((_) async {
      try {
        return await _lockedUpdate(name: name, transform: transform);
      } finally {
        completer.complete();
        if (identical(_updateChains[name], completer.future)) {
          unawaited(_updateChains.remove(name));
        }
      }
    });
  }

  Future<String?> _lockedUpdate({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    await _ensureRuntimeDirectory();

    final lockFile = await File(p.join(runtimeDirectory, '$name$updateLockSuffix')).open(mode: FileMode.append);
    try {
      // An explicit one-byte range: locking an empty file's default (whole)
      // range is platform-dependent, and the lock must also be acquirable by
      // other processes computing the same range.
      await lockFile.lock(FileLock.blockingExclusive, 0, 1);
      try {
        final current = await readFile(name: name);
        final next = await transform(current);
        if (next == null) {
          await deleteFile(name: name);
        } else {
          await writeFile(name: name, contents: next);
        }
        return next;
      } finally {
        await lockFile.unlock(0, 1);
      }
    } finally {
      await lockFile.close();
    }
  }

  Future<bool> acquireStartupLock({required String contents}) async {
    await _ensureRuntimeDirectory();

    final lockFile = File(startupLockFilePath);
    try {
      await lockFile.create(exclusive: true);
    } on PathExistsException {
      return false;
    }

    try {
      await lockFile.writeAsString(contents, flush: true);
      return true;
    } on Object {
      try {
        await lockFile.delete();
      } on Object {
        // Best-effort cleanup of partial lock.
      }
      rethrow;
    }
  }

  Future<void> releaseStartupLock() async {
    final lockFile = File(startupLockFilePath);
    try {
      await lockFile.delete();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !lockFile.existsSync()) {
        return;
      }
      rethrow;
    }
  }

  Future<String?> readStartupLock() async {
    final lockFile = File(startupLockFilePath);
    if (!lockFile.existsSync()) {
      return null;
    }

    try {
      return await lockFile.readAsString();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !lockFile.existsSync()) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _ensureRuntimeDirectory() async {
    final directory = Directory(runtimeDirectory);
    if (directory.existsSync()) {
      return;
    }

    await directory.create(recursive: true);
  }

  static bool _isFileMissing({required FileSystemException error}) {
    final int? code = error.osError?.errorCode;
    if (code == 2) {
      return true;
    }

    final String message = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    return message.contains('no such file') || message.contains('cannot find the file');
  }
}
