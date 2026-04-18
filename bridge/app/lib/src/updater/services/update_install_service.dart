import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../models/file_replacement_result.dart';
import '../models/release_info.dart';
import '../models/update_install_result.dart';
import '../models/update_result.dart';
import '../repositories/installed_file_repository.dart';
import '../repositories/update_artifact_repository.dart';

class UpdateInstallService {
  final UpdateArtifactRepository _updateArtifactRepository;
  final InstalledFileRepository _installedFileRepository;

  UpdateInstallService({
    required UpdateArtifactRepository updateArtifactRepository,
    required InstalledFileRepository installedFileRepository,
  }) : _updateArtifactRepository = updateArtifactRepository,
       _installedFileRepository = installedFileRepository;

  @visibleForTesting
  void Function(String message) writeToStderr = stderr.writeln;

  Future<UpdateInstallResult> performUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    final String archivePath = p.join(
      installRoot,
      Platform.isWindows ? '.sesori-bridge-update.zip' : '.sesori-bridge-update.tar.gz',
    );
    final String stagingPath = p.join(installRoot, '.sesori-bridge-staging');
    var keepWindowsArtifacts = false;

    try {
      final bool isWritable = await _isDirectoryWritable(directoryPath: installRoot);
      if (!isWritable) {
        return const UpdateInstallResult.completed(result: UpdateResult.permissionDenied);
      }

      final UpdateResult downloadResult = await _updateArtifactRepository.downloadArchive(
        release: release,
        archivePath: archivePath,
      );
      if (downloadResult != UpdateResult.success) {
        return UpdateInstallResult.completed(result: downloadResult);
      }

      final bool checksumValid = await _updateArtifactRepository.verifyDownloadedArchive(
        archivePath: archivePath,
        release: release,
      );
      if (!checksumValid) {
        return const UpdateInstallResult.completed(result: UpdateResult.checksumFailed);
      }

      final bool extracted = await _updateArtifactRepository.extractArchive(
        archivePath: archivePath,
        stagingPath: stagingPath,
      );
      if (!extracted) {
        return const UpdateInstallResult.completed(result: UpdateResult.downloadFailed);
      }

      final FileReplacementResult replacementResult = await _installedFileRepository.replaceInstalledFiles(
        installRoot: installRoot,
        stagingPath: stagingPath,
      );
      if (!replacementResult.success) {
        return const UpdateInstallResult.completed(result: UpdateResult.permissionDenied);
      }

      return switch (replacementResult.pendingWindowsUpdate) {
        final pendingWindowsUpdate? => () {
          keepWindowsArtifacts = Platform.isWindows;
          return UpdateInstallResult.pending(pendingWindowsUpdate: pendingWindowsUpdate);
        }(),
        null => const UpdateInstallResult.completed(result: UpdateResult.success),
      };
    } on SocketException {
      return const UpdateInstallResult.completed(result: UpdateResult.networkError);
    } on HttpException {
      return const UpdateInstallResult.completed(result: UpdateResult.networkError);
    } on TimeoutException {
      return const UpdateInstallResult.completed(result: UpdateResult.networkError);
    } on FileSystemException catch (error) {
      if (isPermissionDenied(error: error)) {
        return const UpdateInstallResult.completed(result: UpdateResult.permissionDenied);
      }
      return const UpdateInstallResult.completed(result: UpdateResult.downloadFailed);
    } on Object catch (error, stackTrace) {
      writeToStderr('Warning: updater failed unexpectedly: $error\n$stackTrace');
      return const UpdateInstallResult.completed(result: UpdateResult.downloadFailed);
    } finally {
      if (!keepWindowsArtifacts) {
        await _cleanup(path: archivePath, recursive: false);
        await _cleanup(path: stagingPath, recursive: true);
      }
    }
  }

  Future<bool> _isDirectoryWritable({required String directoryPath}) async {
    final String markerPath = p.join(
      directoryPath,
      '.write-check-${DateTime.now().microsecondsSinceEpoch}',
    );
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
