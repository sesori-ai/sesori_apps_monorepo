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

import "runtime_candidate_validator.dart";
import "runtime_manifest.dart";

/// Classifies install failures that require distinct safe client guidance.
enum RuntimeInstallFailureKind() {
  general,
  candidateValidation,
}

/// Raised when a managed runtime cannot be installed (download, checksum,
/// extraction, validation, or placement failure). The provision service maps
/// this to a non-fatal `ProvisionFailed`.
class const RuntimeInstallException(
  final String message, {
  final RuntimeInstallFailureKind kind = RuntimeInstallFailureKind.general,
}) implements Exception {
  @override
  String toString() => "RuntimeInstallException: $message";
}

/// Installs a pinned managed runtime: download → checksum-verify → extract →
/// place the binary at `<versionDir>/<binaryFileName>` → write a verification
/// sentinel.
///
/// Archive executables are located by [ArchiveRuntimeAsset.archiveBinaryName]
/// (a name or package-relative path) and normalized to [binaryFileName]. Direct
/// binaries are placed there without extraction. The sentinel (the verified
/// SHA-256) is written last, so an
/// interrupted install leaves no sentinel and is cleanly redone next attempt.
/// No lock is required: single-live-bridge enforcement covers cross-process
/// overlap, callers gate concurrent same-plugin work (management commands are
/// serialized per plugin), the binary lands via atomic rename, and the sentinel
/// is written last — so any residual race self-heals on the next attempt.
/// Staging paths are fixed and self-healing. The plugin may be running from an
/// older managed version directory throughout; placement only ever touches the
/// pinned version directory and this runtime's staging paths.
class RuntimeInstallService({
  required final BinaryDownloadClient _downloadClient,
  required final ChecksumValidator _checksumValidator,
  required final ArchiveExtractor _archiveExtractor,
  required final CommandExecutor _commandExecutor,
  required final RuntimeCandidateValidator _candidateValidator,
  required final String _runtimeId,
}) {
  static const String sentinelFileName = ".sesori-runtime-sha256";
  static const String _downloadFileName = ".sesori-runtime-download";
  static const String _stagingDirName = ".sesori-runtime-staging";
  static const String _candidateDirName = "candidate";
  static const String _validationWorkingDirName = "validation-cwd";
  static const String _validationStateDirName = "validation-state";

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

  /// Validates an already-installed candidate in the same disposable private
  /// staging context used for a newly downloaded candidate.
  Future<bool> validateCachedCandidate({
    required String managedDir,
    required String executablePath,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    final String stagingPath = p.join(managedDir, _stagingDirName);
    try {
      await _preparePrivateStaging(stagingPath: stagingPath);
      return await _validateCandidate(
        executablePath: executablePath,
        stagingPath: stagingPath,
        environment: environment,
        startAborted: startAborted,
      );
    } finally {
      await _deleteQuietly(Directory(stagingPath));
    }
  }

  /// Downloads, verifies, validates and places [asset] at
  /// `<versionDir>/<binaryFileName>`, emitting progress. Throws
  /// [RuntimeInstallException] on failure and [PluginStartAbortedException] when
  /// [startAborted] fires. Validation and its cleanup settle before placement.
  Stream<RuntimeProvisionProgress> install({
    required String managedDir,
    required String versionDir,
    required String binaryFileName,
    required String downloadUrl,
    required RuntimeAsset asset,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async* {
    Directory(managedDir).createSync(recursive: true);
    // The on-disk extension must match the archive format: Windows extraction
    // shells out to PowerShell `Expand-Archive`, which rejects any source path
    // that does not end in `.zip` (a bare extensionless file fails the install).
    // The format is the same source of truth the extractor switches on.
    final String extension = switch (asset) {
      ArchiveRuntimeAsset(:final format) => format.fileExtension,
      DirectBinaryRuntimeAsset() => "",
    };
    final String downloadPath = p.join(managedDir, "$_downloadFileName$extension");
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

      await _preparePrivateStaging(stagingPath: stagingPath);
      final String candidatePath = p.join(stagingPath, _candidateDirName);
      final File binaryInStaging;
      switch (asset) {
        case ArchiveRuntimeAsset():
          yield const ProvisionExtracting();
          final ArchiveExtractionResult extracted = await _archiveExtractor.extract(
            archivePath: downloadPath,
            stagingPath: candidatePath,
            format: asset.format,
            archiveCommandTimeout: asset.archiveCommandTimeout,
          );
          if (!extracted.succeeded) {
            throw RuntimeInstallException("failed to extract ${asset.assetName} (${extracted.failureReason})");
          }
          _throwIfAborted(startAborted);

          final File? locatedBinary = _locateBinary(
            stagingPath: candidatePath,
            archiveBinaryName: asset.archiveBinaryName,
          );
          if (locatedBinary == null) {
            throw RuntimeInstallException("archive ${asset.assetName} did not contain ${asset.archiveBinaryName}");
          }
          binaryInStaging = locatedBinary;
        case DirectBinaryRuntimeAsset():
          Directory(candidatePath).createSync(recursive: true);
          binaryInStaging = await File(downloadPath).rename(p.join(candidatePath, binaryFileName));
      }

      await _makeExecutable(binaryPath: binaryInStaging.path, assetName: asset.assetName);
      _throwIfAborted(startAborted);
      final bool candidateValid = await _validateCandidate(
        executablePath: binaryInStaging.path,
        stagingPath: stagingPath,
        environment: environment,
        startAborted: startAborted,
      );
      _throwIfAborted(startAborted);
      if (!candidateValid) {
        throw RuntimeInstallException(
          "candidate validation failed for ${asset.assetName}",
          kind: RuntimeInstallFailureKind.candidateValidation,
        );
      }

      switch (asset) {
        case ArchiveRuntimeAsset(layout: RuntimeArchiveLayout.packageDirectory):
          _placePackage(
            binaryInStaging: binaryInStaging,
            versionDir: versionDir,
            binaryFileName: binaryFileName,
            archiveBinaryName: asset.archiveBinaryName,
          );
        case ArchiveRuntimeAsset(layout: RuntimeArchiveLayout.singleBinary) || DirectBinaryRuntimeAsset():
          _placeBinary(binaryInStaging: binaryInStaging, versionDir: versionDir, binaryFileName: binaryFileName);
      }

      // Sentinel written last: its presence (with a matching hash) is the only
      // signal isInstalled() trusts, so a crash before this point is redone.
      File(p.join(versionDir, sentinelFileName)).writeAsStringSync(asset.sha256);
    } finally {
      await _deleteQuietly(File(downloadPath));
      await _deleteQuietly(Directory(stagingPath));
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
    final String normalizedArchivePath = p.normalize(archiveBinaryName);
    final List<String> expectedSegments = p.split(normalizedArchivePath);
    if (!dir.existsSync() ||
        p.isAbsolute(normalizedArchivePath) ||
        expectedSegments.isEmpty ||
        expectedSegments.any((segment) => segment == "..")) {
      return null;
    }
    for (final FileSystemEntity entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final List<String> actualSegments = p.split(p.relative(entity.path, from: stagingPath));
      if (_pathEndsWith(actual: actualSegments, expected: expectedSegments)) {
        return entity;
      }
    }
    return null;
  }

  bool _pathEndsWith({required List<String> actual, required List<String> expected}) {
    if (actual.length < expected.length) {
      return false;
    }
    final int offset = actual.length - expected.length;
    for (var index = 0; index < expected.length; index++) {
      if (actual[offset + index] != expected[index]) {
        return false;
      }
    }
    return true;
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
    final File canonicalBinary = File(p.join(versionDir, binaryFileName));
    canonicalBinary.parent.createSync(recursive: true);
    binaryInStaging.renameSync(canonicalBinary.path);
  }

  /// Places an entire extracted package tree at [versionDir], keeping the entry
  /// binary next to the siblings it loads at runtime. A package-relative
  /// [archiveBinaryName] identifies how far above the entry the package root
  /// begins. When that path differs from the canonical [binaryFileName], the
  /// entry file is renamed inside the placed tree rather than moved out of it.
  void _placePackage({
    required File binaryInStaging,
    required String versionDir,
    required String binaryFileName,
    required String archiveBinaryName,
  }) {
    final String normalizedArchiveBinaryName = p.normalize(archiveBinaryName);
    final String normalizedBinaryFileName = p.normalize(binaryFileName);
    final List<String> archivePathSegments = p.split(normalizedArchiveBinaryName);
    Directory packageInStaging = binaryInStaging.parent;
    for (var index = 1; index < archivePathSegments.length; index++) {
      packageInStaging = packageInStaging.parent;
    }

    final Directory dir = Directory(versionDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.parent.createSync(recursive: true);
    // Same filesystem (both under managedDir), so this rename is atomic.
    packageInStaging.renameSync(versionDir);
    if (normalizedArchiveBinaryName != normalizedBinaryFileName) {
      final File canonicalBinary = File(p.join(versionDir, normalizedBinaryFileName));
      canonicalBinary.parent.createSync(recursive: true);
      File(p.join(versionDir, normalizedArchiveBinaryName)).renameSync(canonicalBinary.path);
    }
  }

  Future<void> _preparePrivateStaging({required String stagingPath}) async {
    if (!await _deleteQuietly(Directory(stagingPath))) {
      throw const RuntimeInstallException("failed to remove stale managed runtime staging");
    }
    Directory(stagingPath).createSync(recursive: true);
    await _makeOwnerOnly(directoryPath: stagingPath);
  }

  Future<bool> _validateCandidate({
    required String executablePath,
    required String stagingPath,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    final String workingDirectory = p.join(stagingPath, _validationWorkingDirName);
    final String stateDirectory = p.join(stagingPath, _validationStateDirName);
    Directory(workingDirectory).createSync();
    Directory(stateDirectory).createSync();
    await _makeOwnerOnly(directoryPath: workingDirectory);
    await _makeOwnerOnly(directoryPath: stateDirectory);
    _throwIfAborted(startAborted);
    final bool candidateValid;
    try {
      candidateValid = await _candidateValidator.validate(
        context: RuntimeCandidateValidationContext(
          executablePath: executablePath,
          workingDirectory: workingDirectory,
          stateDirectory: stateDirectory,
          environment: environment,
          abortSignal: startAborted,
        ),
      );
    } on Object {
      // Preserve the validator's controlling error while still awaiting both
      // best-effort cleanup operations.
      await _deleteQuietly(Directory(workingDirectory));
      await _deleteQuietly(Directory(stateDirectory));
      rethrow;
    }

    // Validator-owned state and cwd are gone before a successful candidate can
    // be placed. Cleanup failure rejects the candidate rather than activating
    // it with validation state left behind.
    final bool workingDirectoryRemoved = await _deleteQuietly(Directory(workingDirectory));
    final bool stateDirectoryRemoved = await _deleteQuietly(Directory(stateDirectory));
    if (!workingDirectoryRemoved || !stateDirectoryRemoved) {
      throw const RuntimeInstallException("failed to remove managed runtime validation context");
    }
    return candidateValid;
  }

  Future<void> _makeOwnerOnly({required String directoryPath}) async {
    if (Platform.isWindows) {
      // Managed staging lives below the user's private profile, matching the
      // existing managed-runtime and Antigravity profile trust boundary.
      return;
    }
    final CommandResult result = await _commandExecutor.run("chmod", ["700", directoryPath]);
    if (result.exitCode != 0) {
      throw RuntimeInstallException(
        "failed to make managed runtime validation private (chmod exit ${result.exitCode}): ${result.stderr.trim()}",
      );
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

  Future<bool> _deleteQuietly(FileSystemEntity entity) {
    return Future<bool>.sync(() {
      try {
        if (entity.existsSync()) {
          entity.deleteSync(recursive: true);
        }
        return true;
      } on Object catch (error, stackTrace) {
        Log.w("[$_runtimeId] best-effort cleanup of '${entity.path}' failed", error, stackTrace);
        return false;
      }
    });
  }
}
