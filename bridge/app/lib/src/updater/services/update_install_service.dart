import 'dart:io';

import 'package:path/path.dart' as p;

import '../../foundation/filesystem_cleaner.dart';
import '../../foundation/filesystem_permission_validator.dart';
import '../foundation/update_policy.dart';
import '../models/release_info.dart';
import '../models/update_install_result.dart';
import '../models/update_result.dart';
import '../repositories/update_artifact_repository.dart';

/// Stages an update payload: download → checksum-verify → extract into a staging
/// directory. It performs no swap and makes no apply decisions — on success it
/// returns the [UpdateInstallResult.stagingPath] for the apply step to consume.
///
/// The archive + staging paths live under the install root (they must share a
/// filesystem with it so the apply step can rename rather than copy). Pass a
/// `null` [workspaceLabel] to use the shared, fixed paths. A separate,
/// concurrent stager — e.g. an explicit `update` process running while a
/// resident bridge's background updater is mid-stage — passes a distinct
/// [workspaceLabel] so the two do not clobber each other's archive/staging on
/// the way to the lock-guarded swap.
class UpdateInstallService({
  required final UpdateArtifactRepository _updateArtifactRepository,
  required final FilesystemCleaner _filesystemCleaner,
  required final String? _workspaceLabel,
}) {
  Future<UpdateInstallResult> stageUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    final String suffix = _workspaceLabel == null ? '' : '.$_workspaceLabel';
    final String archivePath = p.join(
      installRoot,
      Platform.isWindows ? '.sesori-bridge-update$suffix.zip' : '.sesori-bridge-update$suffix.tar.gz',
    );
    final String stagingPath = p.join(installRoot, '.sesori-bridge-staging$suffix');
    var staged = false;

    try {
      final bool isWritable = await _isDirectoryWritable(directoryPath: installRoot);
      if (!isWritable) {
        return const UpdateInstallStageFailed(result: UpdateResult.permissionDenied);
      }

      final UpdateResult? downloadFailure = await _updateArtifactRepository.downloadArchive(
        release: release,
        archivePath: archivePath,
      );
      if (downloadFailure != null) {
        return UpdateInstallStageFailed(result: downloadFailure);
      }

      final bool checksumValid = await _updateArtifactRepository.verifyDownloadedArchive(
        archivePath: archivePath,
        release: release,
      );
      if (!checksumValid) {
        return const UpdateInstallStageFailed(result: UpdateResult.checksumFailed);
      }

      final bool extracted = await _updateArtifactRepository.extractArchive(
        archivePath: archivePath,
        stagingPath: stagingPath,
      );
      if (!extracted) {
        return const UpdateInstallStageFailed(result: UpdateResult.downloadFailed);
      }

      staged = true;
      return UpdateInstallStaged(stagingPath: stagingPath);
    } on FileSystemException catch (error) {
      if (isPermissionDenied(error: error)) {
        return const UpdateInstallStageFailed(result: UpdateResult.permissionDenied);
      }
      return const UpdateInstallStageFailed(result: UpdateResult.downloadFailed);
    } on Object catch (error) {
      if (isTransientNetworkError(error)) {
        return const UpdateInstallStageFailed(result: UpdateResult.networkError);
      }
      rethrow;
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
    // The shared validator covers EPERM(1)/EACCES(13) and permission messages.
    // The updater additionally treats EIO(5) as a denial because a read-only or
    // failing install volume must abort the apply just like a permission error.
    if (const FilesystemPermissionValidator().isPermissionDenied(error)) {
      return true;
    }
    return error.osError?.errorCode == 5;
  }
}
