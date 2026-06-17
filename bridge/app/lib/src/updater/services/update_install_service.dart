import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../foundation/filesystem_cleaner.dart';
import '../models/release_info.dart';
import '../models/update_install_result.dart';
import '../models/update_result.dart';
import '../repositories/update_artifact_repository.dart';

/// Stages an update payload: download → checksum-verify → extract into a staging
/// directory. It performs no swap and makes no apply decisions — on success it
/// returns the [UpdateInstallResult.stagingPath] for the apply step to consume.
class UpdateInstallService {
  UpdateInstallService({
    required UpdateArtifactRepository updateArtifactRepository,
    required FilesystemCleaner filesystemCleaner,
  }) : _updateArtifactRepository = updateArtifactRepository,
       _filesystemCleaner = filesystemCleaner;

  final UpdateArtifactRepository _updateArtifactRepository;
  final FilesystemCleaner _filesystemCleaner;

  Future<UpdateInstallResult> stageUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    final String archivePath = p.join(
      installRoot,
      Platform.isWindows ? '.sesori-bridge-update.zip' : '.sesori-bridge-update.tar.gz',
    );
    final String stagingPath = p.join(installRoot, '.sesori-bridge-staging');
    var staged = false;

    try {
      final bool isWritable = await _isDirectoryWritable(directoryPath: installRoot);
      if (!isWritable) {
        return const UpdateInstallResult.failed(result: UpdateResult.permissionDenied);
      }

      final UpdateResult downloadResult = await _updateArtifactRepository.downloadArchive(
        release: release,
        archivePath: archivePath,
      );
      if (downloadResult != UpdateResult.success) {
        return UpdateInstallResult.failed(result: downloadResult);
      }

      final bool checksumValid = await _updateArtifactRepository.verifyDownloadedArchive(
        archivePath: archivePath,
        release: release,
      );
      if (!checksumValid) {
        return const UpdateInstallResult.failed(result: UpdateResult.checksumFailed);
      }

      final bool extracted = await _updateArtifactRepository.extractArchive(
        archivePath: archivePath,
        stagingPath: stagingPath,
      );
      if (!extracted) {
        return const UpdateInstallResult.failed(result: UpdateResult.downloadFailed);
      }

      staged = true;
      return UpdateInstallResult.staged(stagingPath: stagingPath);
    } on SocketException {
      return const UpdateInstallResult.failed(result: UpdateResult.networkError);
    } on HttpException {
      return const UpdateInstallResult.failed(result: UpdateResult.networkError);
    } on TimeoutException {
      return const UpdateInstallResult.failed(result: UpdateResult.networkError);
    } on FileSystemException catch (error) {
      if (isPermissionDenied(error: error)) {
        return const UpdateInstallResult.failed(result: UpdateResult.permissionDenied);
      }
      return const UpdateInstallResult.failed(result: UpdateResult.downloadFailed);
    } finally {
      // The archive is never needed past extraction; the staging directory is
      // the output handed to the apply step, so it is kept only on success.
      await _filesystemCleaner.delete(path: archivePath, recursive: false);
      if (!staged) {
        await _filesystemCleaner.delete(path: stagingPath, recursive: true);
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
    } on FileSystemException {
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
}
