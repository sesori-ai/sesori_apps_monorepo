import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../models/release_info.dart';
import '../models/update_result.dart';
import '../platform_info.dart';
import '../repositories/installed_file_repository.dart';
import '../repositories/update_artifact_repository.dart';
import '../update_lock.dart';

class UpdateInstallerService {
  final UpdateArtifactRepository _updateArtifactRepository;
  final UpdateLock _updateLock;
  final InstalledFileRepository _installedFileRepository;

  UpdateInstallerService({
    required UpdateArtifactRepository updateArtifactRepository,
    required UpdateLock updateLock,
    required InstalledFileRepository installedFileRepository,
  }) : _updateArtifactRepository = updateArtifactRepository,
       _updateLock = updateLock,
       _installedFileRepository = installedFileRepository;

  @visibleForTesting
  void Function(String message) writeToStderr = stderr.writeln;

  Future<UpdateResult> performUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    final String lockPath = p.join(installRoot, '.update.lock');
    final String archivePath = p.join(
      installRoot,
      Platform.isWindows ? '.sesori-bridge-update.zip' : '.sesori-bridge-update.tar.gz',
    );
    final String stagingPath = p.join(installRoot, '.sesori-bridge-staging');
    final File lockFile = File(lockPath);

    try {
      return await _updateLock.locked<UpdateResult>(
        lockFile: lockFile,
        shouldReleaseLock: (result) {
          return !(Platform.isWindows &&
              result == UpdateResult.success &&
              _installedFileRepository.pendingWindowsUpdate != null);
        },
        onLockRejected: (lockResult) async {
          switch (lockResult) {
            case LockAcquireResult.alreadyLocked:
              return UpdateResult.alreadyLocked;
            case LockAcquireResult.permissionDenied:
              return UpdateResult.permissionDenied;
            case LockAcquireResult.acquired:
              throw StateError('Unexpected acquired state in onLockRejected');
          }
        },
        onLockAcquired: () async {
          final bool isWritable = await _isDirectoryWritable(directoryPath: installRoot);
          if (!isWritable) {
            return UpdateResult.permissionDenied;
          }

          final UpdateResult downloadResult = await _updateArtifactRepository.downloadArchive(
            release: release,
            archivePath: archivePath,
          );
          if (downloadResult != UpdateResult.success) {
            return downloadResult;
          }

          final bool checksumValid = await _updateArtifactRepository.verifyDownloadedArchive(
            archivePath: archivePath,
            release: release,
          );
          if (!checksumValid) {
            return UpdateResult.checksumFailed;
          }

          final bool extracted = await _updateArtifactRepository.extractArchive(
            archivePath: archivePath,
            stagingPath: stagingPath,
          );
          if (!extracted) {
            return UpdateResult.downloadFailed;
          }

          final bool replaced = await _installedFileRepository.replaceInstalledFiles(
            installRoot: installRoot,
            stagingPath: stagingPath,
          );
          if (!replaced) {
            return UpdateResult.permissionDenied;
          }

          return UpdateResult.success;
        },
      );
    } on SocketException {
      return UpdateResult.networkError;
    } on HttpException {
      return UpdateResult.networkError;
    } on TimeoutException {
      return UpdateResult.networkError;
    } on FileSystemException catch (error) {
      if (isPermissionDenied(error: error)) {
        return UpdateResult.permissionDenied;
      }
      return UpdateResult.downloadFailed;
    } on Object catch (error, stackTrace) {
      writeToStderr('Warning: updater failed unexpectedly: $error\n$stackTrace');
      return UpdateResult.downloadFailed;
    } finally {
      final bool keepWindowsArtifacts = Platform.isWindows && _installedFileRepository.pendingWindowsUpdate != null;
      if (!keepWindowsArtifacts) {
        await _cleanup(path: archivePath, recursive: false);
        await _cleanup(path: stagingPath, recursive: true);
      }
    }
  }

  Future<Never> reExec({required List<String> args}) async {
    if (Platform.isWindows && _installedFileRepository.pendingWindowsUpdate != null) {
      final String scriptPath = await _installedFileRepository.createWindowsSwapScript(args: args);
      // Intentional direct handoff: this detaches the updater apply script instead of running a bounded tool.
      await Process.start(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    final String binaryPath = getBinaryPath();
    // Intentional direct handoff: after a successful update we replace the current process with the managed binary.
    await Process.start(
      binaryPath,
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    exit(0);
  }

  Future<bool> _isDirectoryWritable({required String directoryPath}) async {
    final String markerPath = p.join(directoryPath, '.write-check-${DateTime.now().microsecondsSinceEpoch}');
    final File markerFile = File(markerPath);
    try {
      await markerFile.writeAsString('ok', flush: true);
      await markerFile.delete();
      return true;
    } on FileSystemException catch (error) {
      if (isPermissionDenied(error: error)) {
        return false;
      }
      return false;
    } on Object catch (error, stackTrace) {
      writeToStderr('Warning: failed to verify updater write access: $error\n$stackTrace');
      return false;
    }
  }

  static bool isPermissionDenied({required FileSystemException error}) {
    final int? code = error.osError?.errorCode;
    if (code == 13 || code == 5) {
      return true;
    }
    final String message = '${error.osError?.message ?? ''} ${error.message}'.toLowerCase();
    return message.contains('permission denied') || message.contains('access is denied');
  }

  static Future<void> cleanupPath({required String path, required bool recursive}) async {
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

  Future<void> _cleanup({required String path, required bool recursive}) {
    return cleanupPath(path: path, recursive: recursive);
  }
}
