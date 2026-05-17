import 'dart:io';

import 'package:path/path.dart' as p;

class RuntimeFileApi {
  final String runtimeDirectory;

  RuntimeFileApi({required this.runtimeDirectory});

  String get ownershipFilePath => p.join(runtimeDirectory, 'opencode-processes.json');

  String get startupLockFilePath => p.join(runtimeDirectory, 'bridge-startup.lock');

  Future<String?> readOwnershipFile() async {
    final file = File(ownershipFilePath);
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

  Future<void> writeOwnershipFile({required String contents}) async {
    await _ensureRuntimeDirectory();

    final targetFile = File(ownershipFilePath);
    final tmpFile = File('$ownershipFilePath.tmp');
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

  Future<void> deleteOwnershipFile() async {
    final file = File(ownershipFilePath);
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      if (_isFileMissing(error: error) || !file.existsSync()) {
        return;
      }
      rethrow;
    }
  }

  Future<void> renameOwnershipFile({required String fileName}) async {
    final sourceFile = File(ownershipFilePath);
    if (!sourceFile.existsSync()) {
      return;
    }

    final targetFile = File(p.join(runtimeDirectory, fileName));
    await sourceFile.rename(targetFile.path);
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
