import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "command_executor.dart";

/// The on-disk container format of a runtime archive. Selected explicitly by the
/// caller rather than inferred from the host OS, because publishers ship
/// different formats per platform (e.g. OpenCode ships `.zip` on macOS but
/// `.tar.gz` on Linux).
enum ArchiveFormat { tarGz, zip }

/// The outcome of an [ArchiveExtractor.extract] attempt.
///
/// On failure, [failureReason] carries the underlying cause (the failing tool's
/// exit code + stderr, or which hardening check rejected the payload) so the
/// caller can surface it instead of a bare "extraction failed". A swallowed
/// extractor error is otherwise invisible — the platform tool's stderr is the
/// only signal of what actually went wrong (corrupt archive, missing tool,
/// permission denied, PowerShell constrained-language mode, …).
class ArchiveExtractionResult {
  const ArchiveExtractionResult.success() : succeeded = true, failureReason = null;
  const ArchiveExtractionResult.failure({required String reason}) : succeeded = false, failureReason = reason;

  final bool succeeded;
  final String? failureReason;
}

/// Extracts a downloaded runtime archive into a staging directory.
///
/// The archive has already been checksum-verified, but extraction is still
/// hardened against a malformed/tampered payload: archive members that would
/// escape the staging directory (absolute paths or `..` traversal) are rejected
/// before extraction, and any symlink in the extracted tree is rejected
/// afterwards. Published runtime payloads contain only regular files and
/// directories, so either is a sign of tampering — extraction fails closed.
class ArchiveExtractor {
  final CommandExecutor _commandExecutor;

  ArchiveExtractor({required CommandExecutor commandExecutor}) : _commandExecutor = commandExecutor;

  static const Duration _listTimeout = Duration(seconds: 30);
  static const Duration _extractTimeout = Duration(minutes: 2);

  Future<ArchiveExtractionResult> extract({
    required String archivePath,
    required String stagingPath,
    required ArchiveFormat format,
  }) async {
    final Directory stagingDir = Directory(stagingPath);
    if (stagingDir.existsSync()) {
      stagingDir.deleteSync(recursive: true);
    }
    stagingDir.createSync(recursive: true);

    // The helpers shell out via the command executor, which can throw rather
    // than return a non-zero result (e.g. the tool is missing/not executable —
    // ProcessException — or a hung command is force-killed past its timeout —
    // TimeoutException). Convert those into a structured failure so callers
    // always observe the cause instead of an unhandled async error.
    final ArchiveExtractionResult extracted;
    try {
      extracted = await switch (format) {
        ArchiveFormat.tarGz => _extractTarGz(archivePath: archivePath, stagingPath: stagingPath),
        ArchiveFormat.zip => Platform.isWindows
            ? _extractZipWindows(archivePath: archivePath, stagingPath: stagingPath)
            : _extractZipPosix(archivePath: archivePath, stagingPath: stagingPath),
      };
    } on Object catch (error, stackTrace) {
      final String reason = "extraction command failed to run: $error";
      Log.w("Archive extraction command threw", error, stackTrace);
      _deleteQuietly(stagingDir);
      return ArchiveExtractionResult.failure(reason: reason);
    }
    if (!extracted.succeeded) {
      return extracted;
    }

    // A symlink could point outside the install root and be followed when the
    // extracted tree is placed (a wholesale directory rename preserves links) or
    // on a later launch — escaping the sandbox. Payloads never ship symlinks, so
    // reject the whole staged tree if any are present.
    if (_containsSymlink(stagingDir)) {
      const String reason = "the archive contains symlink entries";
      Log.w("Rejecting archive payload: $reason.");
      _deleteQuietly(stagingDir);
      return const ArchiveExtractionResult.failure(reason: reason);
    }
    return const ArchiveExtractionResult.success();
  }

  Future<ArchiveExtractionResult> _extractTarGz({
    required String archivePath,
    required String stagingPath,
  }) async {
    // Defence-in-depth over tar's own refusal of absolute/`..` members: list the
    // archive and reject any member that would resolve outside the staging dir
    // before writing anything.
    final CommandResult listing = await _commandExecutor.run("tar", ["-tzf", archivePath], timeout: _listTimeout);
    if (listing.exitCode != 0) {
      return ArchiveExtractionResult.failure(reason: _toolFailure(tool: "tar -tzf", result: listing));
    }
    final String? escapeReason = _firstEscapingMember(stagingPath: stagingPath, listing: listing.stdout);
    if (escapeReason != null) {
      return ArchiveExtractionResult.failure(reason: escapeReason);
    }

    final CommandResult result = await _commandExecutor.run(
      "tar",
      ["-xzf", archivePath, "-C", stagingPath],
      timeout: _extractTimeout,
    );
    if (result.exitCode != 0) {
      return ArchiveExtractionResult.failure(reason: _toolFailure(tool: "tar -xzf", result: result));
    }
    return const ArchiveExtractionResult.success();
  }

  Future<ArchiveExtractionResult> _extractZipPosix({
    required String archivePath,
    required String stagingPath,
  }) async {
    // `unzip -Z1` lists member names one per line (zipinfo mode); reject any that
    // would escape before extracting.
    final CommandResult listing = await _commandExecutor.run("unzip", ["-Z1", archivePath], timeout: _listTimeout);
    if (listing.exitCode != 0) {
      return ArchiveExtractionResult.failure(reason: _toolFailure(tool: "unzip -Z1", result: listing));
    }
    final String? escapeReason = _firstEscapingMember(stagingPath: stagingPath, listing: listing.stdout);
    if (escapeReason != null) {
      return ArchiveExtractionResult.failure(reason: escapeReason);
    }

    final CommandResult result = await _commandExecutor.run(
      "unzip",
      ["-o", "-q", archivePath, "-d", stagingPath],
      timeout: _extractTimeout,
    );
    if (result.exitCode != 0) {
      return ArchiveExtractionResult.failure(reason: _toolFailure(tool: "unzip", result: result));
    }
    return const ArchiveExtractionResult.success();
  }

  Future<ArchiveExtractionResult> _extractZipWindows({
    required String archivePath,
    required String stagingPath,
  }) async {
    // Expand-Archive uses .NET's ZipFile, which rejects path-traversal members.
    final String psArchive = archivePath.replaceAll("'", "''");
    final String psStaging = stagingPath.replaceAll("'", "''");
    final CommandResult result = await _commandExecutor.run(
      "powershell",
      [
        "-NoProfile",
        "-Command",
        "\$ProgressPreference = 'SilentlyContinue'; Expand-Archive -LiteralPath '$psArchive' -DestinationPath '$psStaging' -Force",
      ],
      timeout: _extractTimeout,
    );
    if (result.exitCode != 0) {
      return ArchiveExtractionResult.failure(reason: _toolFailure(tool: "powershell Expand-Archive", result: result));
    }
    return const ArchiveExtractionResult.success();
  }

  /// A one-line description of a failed helper command, including its exit code
  /// and the tail of its stderr (or stdout, if stderr is empty) so the real
  /// cause is visible rather than swallowed.
  String _toolFailure({required String tool, required CommandResult result}) {
    String detail = result.stderr.trim();
    if (detail.isEmpty) {
      detail = result.stdout.trim();
    }
    final String suffix = detail.isEmpty ? "" : ": $detail";
    return "$tool exited with code ${result.exitCode}$suffix";
  }

  String? _firstEscapingMember({required String stagingPath, required String listing}) {
    for (final String line in const LineSplitter().convert(listing)) {
      final String member = line.trim();
      if (member.isEmpty) {
        continue;
      }
      if (_escapesStaging(stagingPath: stagingPath, member: member)) {
        final String reason = "archive member escapes staging: $member";
        Log.w("Rejecting archive payload: $reason");
        return reason;
      }
    }
    return null;
  }

  /// Whether [member] (an archive entry path) would resolve outside [stagingPath]
  /// — an absolute path, or a relative path that escapes via `..`.
  bool _escapesStaging({required String stagingPath, required String member}) {
    if (p.isAbsolute(member)) {
      return true;
    }
    final String normalizedStaging = p.normalize(stagingPath);
    final String resolved = p.normalize(p.join(normalizedStaging, member));
    return resolved != normalizedStaging && !p.isWithin(normalizedStaging, resolved);
  }

  bool _containsSymlink(Directory stagingDir) {
    // followLinks: false returns a symlink as a Link entity and does not recurse
    // through it, so every link in the tree surfaces here.
    for (final FileSystemEntity entity in stagingDir.listSync(recursive: true, followLinks: false)) {
      if (entity is Link) {
        return true;
      }
    }
    return false;
  }

  void _deleteQuietly(Directory dir) {
    try {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } on Object catch (error, stackTrace) {
      // Best-effort: a failed stage is treated as a failure upstream, but record
      // why cleanup of the rejected tree did not complete.
      Log.w("ArchiveExtractor: failed to delete rejected staging tree", error, stackTrace);
    }
  }
}
