import 'dart:io';

import 'package:path/path.dart' as p;

import '../../bridge/foundation/process_runner.dart';
import 'platform_update_api.dart';

/// POSIX (macOS/Linux) in-place update applier.
///
/// The whole `lib/` directory can be renamed while its native libraries are
/// memory-mapped by the running process, so the swap renames the binary and the
/// `lib/` directory wholesale, keeping the displaced originals as `.rollback`
/// siblings until the swap succeeds.
class PosixUpdateApi implements PlatformUpdateApi {
  PosixUpdateApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  static const String _binaryName = 'sesori-bridge';
  static const String _binaryBackupName = '.sesori-bridge.rollback';
  static const String _libBackupName = '.lib.rollback';

  @override
  Future<void> applyInPlace({required String installRoot, required String stagingPath}) async {
    final File newBinary = File(p.join(stagingPath, 'bin', _binaryName));
    final File targetBinary = File(p.join(installRoot, 'bin', _binaryName));
    final File backupBinary = File(p.join(installRoot, 'bin', _binaryBackupName));
    final Directory newLibDir = Directory(p.join(stagingPath, 'lib'));
    final Directory targetLibDir = Directory(p.join(installRoot, 'lib'));
    final Directory backupLibDir = Directory(p.join(installRoot, _libBackupName));

    if (!newBinary.existsSync() || !newLibDir.existsSync()) {
      throw const UpdateApplyException('Staged payload is missing the binary or lib directory.');
    }

    final ProcessResult chmodResult = await _processRunner.run('chmod', ['+x', newBinary.path]);
    if (chmodResult.exitCode != 0) {
      throw UpdateApplyException('Failed to mark the staged binary executable: ${chmodResult.stderr}');
    }

    targetBinary.parent.createSync(recursive: true);
    _deleteIfExists(entity: backupBinary);
    _deleteIfExists(entity: backupLibDir);

    var movedTargetBinary = false;
    var movedNewBinary = false;
    var movedTargetLib = false;
    var movedNewLib = false;

    try {
      if (targetBinary.existsSync()) {
        targetBinary.renameSync(backupBinary.path);
        movedTargetBinary = true;
      }
      newBinary.renameSync(targetBinary.path);
      movedNewBinary = true;

      if (targetLibDir.existsSync()) {
        targetLibDir.renameSync(backupLibDir.path);
        movedTargetLib = true;
      }
      newLibDir.renameSync(targetLibDir.path);
      movedNewLib = true;

      _deleteIfExists(entity: backupBinary);
      _deleteIfExists(entity: backupLibDir);

      if (Platform.isMacOS) {
        await _stripMacOSAttributes(installRoot);
      }
    } on Object {
      _rollback(
        targetBinary: targetBinary,
        newBinary: newBinary,
        backupBinary: backupBinary,
        targetLibDir: targetLibDir,
        newLibDir: newLibDir,
        backupLibDir: backupLibDir,
        movedTargetBinary: movedTargetBinary,
        movedNewBinary: movedNewBinary,
        movedTargetLib: movedTargetLib,
        movedNewLib: movedNewLib,
      );
      rethrow;
    }
  }

  @override
  Future<void> sweepResidue({required String installRoot}) async {
    _deleteIfExists(entity: File(p.join(installRoot, 'bin', _binaryBackupName)));
    _deleteIfExists(entity: Directory(p.join(installRoot, _libBackupName)));
  }

  Future<void> _stripMacOSAttributes(String path) async {
    const List<String> attrs = ['com.apple.quarantine', 'com.apple.provenance'];
    for (final String attr in attrs) {
      try {
        await _processRunner.run('xattr', ['-dr', attr, path]);
      } on Object catch (error) {
        stderr.writeln('Warning: failed to strip $attr from $path: $error');
      }
    }
  }

  void _rollback({
    required File targetBinary,
    required File newBinary,
    required File backupBinary,
    required Directory targetLibDir,
    required Directory newLibDir,
    required Directory backupLibDir,
    required bool movedTargetBinary,
    required bool movedNewBinary,
    required bool movedTargetLib,
    required bool movedNewLib,
  }) {
    try {
      if (movedNewLib && targetLibDir.existsSync()) {
        targetLibDir.renameSync(newLibDir.path);
      }
      if (movedTargetLib && backupLibDir.existsSync()) {
        backupLibDir.renameSync(targetLibDir.path);
      }
    } on Object {
      // Best-effort rollback.
    }

    try {
      if (movedNewBinary && targetBinary.existsSync()) {
        targetBinary.renameSync(newBinary.path);
      }
      if (movedTargetBinary && backupBinary.existsSync()) {
        backupBinary.renameSync(targetBinary.path);
      }
    } on Object {
      // Best-effort rollback.
    }
  }

  void _deleteIfExists({required FileSystemEntity entity}) {
    try {
      if (entity.existsSync()) {
        entity.deleteSync(recursive: true);
      }
    } on Object {
      // Best-effort cleanup.
    }
  }
}
