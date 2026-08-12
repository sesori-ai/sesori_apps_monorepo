import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginStartAbortedException,
        ProvisionDownloading,
        ProvisionExtracting,
        ProvisionVerifying,
        RuntimeProvisionProgress,
        StartAbortSignal;

import "runtime_manifest.dart";

/// Raised when a managed runtime cannot be installed (download, checksum,
/// extraction, or placement failure). The provision service maps this to a
/// non-fatal `ProvisionFailed`.
class const RuntimeInstallException(final String message) implements Exception {
  @override
  String toString() => "RuntimeInstallException: $message";
}

/// Installs a pinned managed runtime: download → checksum-verify → extract →
/// place the binary at `<versionDir>/<binaryFileName>` → write a verification
/// sentinel.
///
/// The executable is located inside the extracted archive by [RuntimeAsset.archiveBinaryName]
/// and moved into a freshly created version directory under the canonical
/// [binaryFileName] (normalizing publishers that ship a target-triple-named
/// member). The sentinel (the verified SHA-256) is written last, so an
/// interrupted install leaves no sentinel and is cleanly redone next attempt.
/// No lock is required: single-live-bridge enforcement covers cross-process
/// overlap, callers gate concurrent same-plugin work (setup-blocked plugins
/// cannot start, and management commands are serialized per plugin), the
/// binary lands via atomic rename, and the sentinel is written last — so any
/// residual race self-heals on the next attempt. Staging paths are fixed and
/// self-healing.
class RuntimeInstallService({
  required final BinaryDownloadClient _downloadClient,
  required final ChecksumValidator _checksumValidator,
  required final ArchiveExtractor _archiveExtractor,
  required final CommandExecutor _commandExecutor,
  required final String _runtimeId,
}) {
  static const String sentinelFileName = ".sesori-runtime-sha256";
  static const String _downloadFileName = ".sesori-runtime-download";
  static const String _stagingDirName = ".sesori-runtime-staging";

  /// Whether [versionDir] already holds a fully-installed binary whose recorded
  /// sentinel matches [sha256] — the "verified once at install" check that lets
  /// a launch skip re-downloading and re-hashing the runtime.
  bool isInstalled({
    required String versionDir,
    required String binaryFileName,
    required String sha256,
  }) {
    final File sentinel = File(p.join(versionDir, sentinelFileName));
    final File binary = File(p.join(versionDir, binaryFileName));
    if (!sentinel.existsSync() || !binary.existsSync()) {
      return false;
    }
    try {
      return sentinel.readAsStringSync().trim().toLowerCase() == sha256.toLowerCase();
    } on Object catch (error, stackTrace) {
      // The bare `false` result (treat as not-installed and reinstall) does not
      // convey why the sentinel could not be read, so log the cause.
      Log.w("[$_runtimeId] managed runtime sentinel unreadable at '$versionDir'", error, stackTrace);
      return false;
    }
  }

  /// Downloads, verifies, extracts and places [asset] at
  /// `<versionDir>/<binaryFileName>`, emitting progress. Throws
  /// [RuntimeInstallException] on failure and [PluginStartAbortedException] when
  /// [startAborted] fires.
  Stream<RuntimeProvisionProgress> install({
    required String managedDir,
    required String versionDir,
    required String binaryFileName,
    required String downloadUrl,
    required RuntimeAsset asset,
    required StartAbortSignal startAborted,
  }) async* {
    Directory(managedDir).createSync(recursive: true);
    // The on-disk extension must match the archive format: Windows extraction
    // shells out to PowerShell `Expand-Archive`, which rejects any source path
    // that does not end in `.zip` (a bare extensionless file fails the install).
    // The format is the same source of truth the extractor switches on.
    final String downloadPath = p.join(managedDir, "$_downloadFileName${asset.format.fileExtension}");
    final String stagingPath = p.join(managedDir, _stagingDirName);

    try {
      yield* _download(url: downloadUrl, destinationPath: downloadPath, startAborted: startAborted);
      _throwIfAborted(startAborted);

      yield const ProvisionVerifying();
      final bool checksumValid = await _checksumValidator.verify(
        filePath: downloadPath,
        expectedHash: asset.sha256,
      );
      if (!checksumValid) {
        throw RuntimeInstallException("checksum verification failed for ${asset.assetName}");
      }
      _throwIfAborted(startAborted);

      yield const ProvisionExtracting();
      final ArchiveExtractionResult extracted = await _archiveExtractor.extract(
        archivePath: downloadPath,
        stagingPath: stagingPath,
        format: asset.format,
      );
      if (!extracted.succeeded) {
        throw RuntimeInstallException("failed to extract ${asset.assetName} (${extracted.failureReason})");
      }
      _throwIfAborted(startAborted);

      final File? binaryInStaging = _locateBinary(stagingPath: stagingPath, archiveBinaryName: asset.archiveBinaryName);
      if (binaryInStaging == null) {
        throw RuntimeInstallException("archive ${asset.assetName} did not contain ${asset.archiveBinaryName}");
      }

      switch (asset.layout) {
        case RuntimeAssetLayout.singleBinary:
          _placeBinary(binaryInStaging: binaryInStaging, versionDir: versionDir, binaryFileName: binaryFileName);
        case RuntimeAssetLayout.packageDirectory:
          // The entry binary loads siblings from its own directory, so the
          // whole tree is placed and the canonical name is a symlink-free
          // rename of the entry file within it.
          _placePackage(
            packageInStaging: binaryInStaging.parent,
            versionDir: versionDir,
            binaryFileName: binaryFileName,
            archiveBinaryName: asset.archiveBinaryName,
          );
      }
      await _makeExecutable(binaryPath: p.join(versionDir, binaryFileName), assetName: asset.assetName);

      // Sentinel written last: its presence (with a matching hash) is the only
      // signal isInstalled() trusts, so a crash before this point is redone.
      File(p.join(versionDir, sentinelFileName)).writeAsStringSync(asset.sha256);
    } finally {
      _deleteQuietly(File(downloadPath));
      _deleteQuietly(Directory(stagingPath));
    }
  }

  Stream<RuntimeProvisionProgress> _download({
    required String url,
    required String destinationPath,
    required StartAbortSignal startAborted,
  }) async* {
    try {
      await for (final DownloadProgress progress in _downloadClient.download(
        url: url,
        destinationPath: destinationPath,
      )) {
        _throwIfAborted(startAborted);
        yield ProvisionDownloading(receivedBytes: progress.receivedBytes, totalBytes: progress.totalBytes);
      }
    } on DownloadException catch (error) {
      throw RuntimeInstallException("download failed: ${error.message}");
    }
  }

  File? _locateBinary({required String stagingPath, required String archiveBinaryName}) {
    final Directory dir = Directory(stagingPath);
    if (!dir.existsSync()) {
      return null;
    }
    for (final FileSystemEntity entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == archiveBinaryName) {
        return entity;
      }
    }
    return null;
  }

  void _placeBinary({
    required File binaryInStaging,
    required String versionDir,
    required String binaryFileName,
  }) {
    final Directory dir = Directory(versionDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
    // Same filesystem (both under managedDir), so this rename is atomic. The
    // canonical [binaryFileName] may differ from the archive member name, which
    // normalizes a target-triple-named member to a plain binary.
    binaryInStaging.renameSync(p.join(versionDir, binaryFileName));
  }

  /// Places an entire extracted package tree at [versionDir], keeping the entry
  /// binary next to the siblings it loads at runtime. When the publisher's
  /// entry name differs from the canonical [binaryFileName], the entry file is
  /// renamed inside the placed tree rather than moved out of it.
  void _placePackage({
    required Directory packageInStaging,
    required String versionDir,
    required String binaryFileName,
    required String archiveBinaryName,
  }) {
    final Directory dir = Directory(versionDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.parent.createSync(recursive: true);
    // Same filesystem (both under managedDir), so this rename is atomic.
    packageInStaging.renameSync(versionDir);
    if (archiveBinaryName != binaryFileName) {
      File(p.join(versionDir, archiveBinaryName)).renameSync(p.join(versionDir, binaryFileName));
    }
  }

  Future<void> _makeExecutable({required String binaryPath, required String assetName}) async {
    if (Platform.isWindows) {
      return;
    }
    final CommandResult result = await _commandExecutor.run("chmod", ["+x", binaryPath]);
    if (result.exitCode != 0) {
      throw RuntimeInstallException(
        "failed to mark $assetName executable (chmod exit ${result.exitCode}): ${result.stderr.trim()}",
      );
    }
  }

  void _throwIfAborted(StartAbortSignal startAborted) {
    if (startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
  }

  void _deleteQuietly(FileSystemEntity entity) {
    try {
      if (entity.existsSync()) {
        entity.deleteSync(recursive: true);
      }
    } on Object catch (error, stackTrace) {
      Log.w("[$_runtimeId] best-effort cleanup of '${entity.path}' failed", error, stackTrace);
    }
  }
}
