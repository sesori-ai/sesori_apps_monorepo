import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../bridge/foundation/process_runner.dart';

/// Extracts a downloaded update archive into a staging directory.
///
/// The archive has already been checksum-verified, but extraction is still
/// hardened against a malformed/tampered payload: archive members that would
/// escape the staging directory (absolute paths or `..` traversal) are rejected
/// before extraction, and any symlink in the extracted tree is rejected
/// afterwards. The published runtime payload contains only regular files and
/// directories, so either is a sign of tampering — extraction fails closed and
/// no swap happens.
class ArchiveExtractorApi {
  final ProcessRunner _processRunner;

  ArchiveExtractorApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<bool> extract({
    required String archivePath,
    required String stagingPath,
  }) async {
    final Directory stagingDir = Directory(stagingPath);
    if (stagingDir.existsSync()) {
      stagingDir.deleteSync(recursive: true);
    }
    stagingDir.createSync(recursive: true);

    final bool extracted = Platform.isWindows
        ? await _extractWindows(archivePath: archivePath, stagingPath: stagingPath)
        : await _extractPosix(archivePath: archivePath, stagingPath: stagingPath);
    if (!extracted) {
      return false;
    }

    // A symlink could point outside the install root and be followed by the
    // in-place applier (the POSIX applier renames `lib/` wholesale, preserving
    // links) or on the next launch — escaping the sandbox. The payload never
    // ships symlinks, so reject the whole staged tree if any are present.
    if (_containsSymlink(stagingDir)) {
      Log.w('Rejecting update payload: the archive contains symlink entries.');
      _deleteQuietly(stagingDir);
      return false;
    }
    return true;
  }

  Future<bool> _extractPosix({
    required String archivePath,
    required String stagingPath,
  }) async {
    // Defence-in-depth over tar's own refusal of absolute/`..` members: list the
    // archive and reject any member that would resolve outside the staging dir
    // before writing anything.
    final ProcessResult listing = await _processRunner.run('tar', ['-tzf', archivePath]);
    if (listing.exitCode != 0) {
      return false;
    }
    for (final String line in const LineSplitter().convert(listing.stdout.toString())) {
      final String member = line.trim();
      if (member.isEmpty) {
        continue;
      }
      if (_escapesStaging(stagingPath: stagingPath, member: member)) {
        Log.w('Rejecting update payload: archive member escapes staging: $member');
        return false;
      }
    }

    final ProcessResult result = await _processRunner.run('tar', ['-xzf', archivePath, '-C', stagingPath]);
    return result.exitCode == 0;
  }

  Future<bool> _extractWindows({
    required String archivePath,
    required String stagingPath,
  }) async {
    // Expand-Archive uses .NET's ZipFile, which rejects path-traversal members.
    final String psArchive = archivePath.replaceAll("'", "''");
    final String psStaging = stagingPath.replaceAll("'", "''");
    final ProcessResult result = await _processRunner.run(
      'powershell',
      [
        '-Command',
        "Expand-Archive -LiteralPath '$psArchive' -DestinationPath '$psStaging' -Force",
      ],
    );
    return result.exitCode == 0;
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
    } on Object {
      // Best-effort: a failed stage is treated as a download failure upstream.
    }
  }
}
