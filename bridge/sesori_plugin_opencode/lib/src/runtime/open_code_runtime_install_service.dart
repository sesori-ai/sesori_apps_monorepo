import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginStartAbortedException, ProvisionDownloading, ProvisionExtracting, ProvisionVerifying, RuntimeProvisionProgress, StartAbortSignal;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "open_code_runtime_manifest.dart";

/// Raised when the managed OpenCode runtime cannot be installed (download,
/// checksum, extraction, or placement failure). The provision service maps this
/// to a non-fatal [ProvisionFailed].
class OpenCodeRuntimeInstallException implements Exception {
  const OpenCodeRuntimeInstallException(this.message);

  final String message;

  @override
  String toString() => "OpenCodeRuntimeInstallException: $message";
}

/// Installs the pinned managed OpenCode runtime: download → checksum-verify →
/// extract → place the binary at `<versionDir>/<binaryFileName>` → write a
/// verification sentinel.
///
/// The single-file OpenCode executable is moved into a freshly created version
/// directory, and the sentinel (the verified SHA-256) is written last, so an
/// interrupted install leaves no sentinel and is cleanly redone next launch.
/// Runs under the bridge startup mutex, so installs are already serialized
/// across bridge instances; staging paths are fixed and self-healing.
class OpenCodeRuntimeInstallService {
  final BinaryDownloadClient _downloadClient;
  final ChecksumValidator _checksumValidator;
  final ArchiveExtractor _archiveExtractor;
  final CommandExecutor _commandExecutor;

  OpenCodeRuntimeInstallService({
    required BinaryDownloadClient downloadClient,
    required ChecksumValidator checksumValidator,
    required ArchiveExtractor archiveExtractor,
    required CommandExecutor commandExecutor,
  }) : _downloadClient = downloadClient,
       _checksumValidator = checksumValidator,
       _archiveExtractor = archiveExtractor,
       _commandExecutor = commandExecutor;

  static const String sentinelFileName = ".sesori-runtime-sha256";

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
    } on Object catch (error) {
      Log.d("[opencode] managed runtime sentinel unreadable at '$versionDir': $error");
      return false;
    }
  }

  /// Downloads, verifies, extracts and places [asset] at
  /// `<versionDir>/<binaryFileName>`, emitting progress. Throws
  /// [OpenCodeRuntimeInstallException] on failure and
  /// [PluginStartAbortedException] when [startAborted] fires.
  Stream<RuntimeProvisionProgress> install({
    required String managedDir,
    required String versionDir,
    required String binaryFileName,
    required String downloadUrl,
    required OpenCodeRuntimeAsset asset,
    required StartAbortSignal startAborted,
  }) async* {
    Directory(managedDir).createSync(recursive: true);
    final String downloadPath = p.join(managedDir, ".opencode-runtime-download");
    final String stagingPath = p.join(managedDir, ".opencode-runtime-staging");

    try {
      yield* _download(url: downloadUrl, destinationPath: downloadPath, startAborted: startAborted);
      _throwIfAborted(startAborted);

      yield const ProvisionVerifying();
      final bool checksumValid = await _checksumValidator.verify(
        filePath: downloadPath,
        expectedHash: asset.sha256,
      );
      if (!checksumValid) {
        throw OpenCodeRuntimeInstallException("checksum verification failed for ${asset.assetName}");
      }
      _throwIfAborted(startAborted);

      yield const ProvisionExtracting();
      final bool extracted = await _archiveExtractor.extract(
        archivePath: downloadPath,
        stagingPath: stagingPath,
        format: asset.format,
      );
      if (!extracted) {
        throw OpenCodeRuntimeInstallException("failed to extract ${asset.assetName}");
      }
      _throwIfAborted(startAborted);

      final File? binaryInStaging = _locateBinary(stagingPath: stagingPath, binaryFileName: binaryFileName);
      if (binaryInStaging == null) {
        throw OpenCodeRuntimeInstallException("archive ${asset.assetName} did not contain $binaryFileName");
      }

      _placeBinary(binaryInStaging: binaryInStaging, versionDir: versionDir, binaryFileName: binaryFileName);
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
      await for (final DownloadProgress progress in _downloadClient.download(url: url, destinationPath: destinationPath)) {
        _throwIfAborted(startAborted);
        yield ProvisionDownloading(receivedBytes: progress.receivedBytes, totalBytes: progress.totalBytes);
      }
    } on DownloadException catch (error) {
      throw OpenCodeRuntimeInstallException("download failed: ${error.message}");
    }
  }

  File? _locateBinary({required String stagingPath, required String binaryFileName}) {
    final Directory dir = Directory(stagingPath);
    if (!dir.existsSync()) {
      return null;
    }
    for (final FileSystemEntity entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == binaryFileName) {
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
    // Same filesystem (both under managedDir), so this rename is atomic.
    binaryInStaging.renameSync(p.join(versionDir, binaryFileName));
  }

  Future<void> _makeExecutable({required String binaryPath, required String assetName}) async {
    if (Platform.isWindows) {
      return;
    }
    final CommandResult result = await _commandExecutor.run("chmod", ["+x", binaryPath]);
    if (result.exitCode != 0) {
      throw OpenCodeRuntimeInstallException(
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
    } on Object catch (error) {
      Log.d("[opencode] best-effort cleanup of '${entity.path}' failed: $error");
    }
  }
}
