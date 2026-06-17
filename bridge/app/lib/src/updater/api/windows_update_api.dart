import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_update_api.dart';

/// Windows in-place update applier.
///
/// Windows lets a *loaded* `.exe`/`.dll` file be renamed but not deleted, and
/// it forbids renaming a directory that contains a loaded DLL. So the binary is
/// renamed aside to `.sesori-bridge.old` and `lib/` is swapped **per file**
/// (each current file renamed into `.lib.old/`, each staged file renamed in) —
/// never by renaming a directory, even when `lib/` has subdirectories. The
/// displaced `.old` artifacts cannot be deleted while this process holds them
/// open, so they are swept on the next launch.
class WindowsUpdateApi implements PlatformUpdateApi {
  const WindowsUpdateApi();

  static const String _binaryName = 'sesori-bridge.exe';
  static const String _binaryBackupName = '.sesori-bridge.old';
  static const String _libBackupName = '.lib.old';

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

    targetBinary.parent.createSync(recursive: true);
    _deleteIfExists(entity: backupBinary);
    _deleteIfExists(entity: backupLibDir);
    backupLibDir.createSync(recursive: true);
    targetLibDir.createSync(recursive: true);

    final List<_Move> performed = <_Move>[];
    try {
      if (targetBinary.existsSync()) {
        _moveFile(performed: performed, from: targetBinary, toPath: backupBinary.path);
      }
      _moveFile(performed: performed, from: newBinary, toPath: targetBinary.path);

      // Displace the currently-installed lib files into the backup, per file —
      // a loaded DLL file can be renamed, the directory cannot.
      _swapFiles(performed: performed, fromDir: targetLibDir, toDir: backupLibDir);
      // Move the staged lib files into place, per file.
      _swapFiles(performed: performed, fromDir: newLibDir, toDir: targetLibDir);
    } on Object {
      _rollback(performed: performed);
      rethrow;
    }
  }

  @override
  Future<void> sweepResidue({required String installRoot}) async {
    _deleteIfExists(entity: File(p.join(installRoot, 'bin', _binaryBackupName)));
    _deleteIfExists(entity: Directory(p.join(installRoot, _libBackupName)));
  }

  /// Moves every regular file under [fromDir] (recursively) into [toDir],
  /// preserving relative paths and recreating parent directories — never
  /// renaming a directory.
  void _swapFiles({
    required List<_Move> performed,
    required Directory fromDir,
    required Directory toDir,
  }) {
    // followLinks: false so a symlink inside the payload can never redirect the
    // swap to rename files outside fromDir (links are returned as Link entities
    // and skipped by the `is! File` guard below).
    for (final FileSystemEntity entity in fromDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final String relative = p.relative(entity.path, from: fromDir.path);
      final String destPath = p.join(toDir.path, relative);
      Directory(p.dirname(destPath)).createSync(recursive: true);
      _moveFile(performed: performed, from: entity, toPath: destPath);
    }
  }

  void _moveFile({
    required List<_Move> performed,
    required File from,
    required String toPath,
  }) {
    from.renameSync(toPath);
    performed.add(_Move(fromPath: from.path, toPath: toPath));
  }

  void _rollback({required List<_Move> performed}) {
    for (final _Move move in performed.reversed) {
      try {
        final File moved = File(move.toPath);
        if (moved.existsSync()) {
          Directory(p.dirname(move.fromPath)).createSync(recursive: true);
          moved.renameSync(move.fromPath);
        }
      } on Object {
        // Best-effort rollback; keep reversing the remaining moves.
      }
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

/// A single file rename performed during an apply, recorded so it can be
/// reversed if a later step fails.
class _Move {
  const _Move({required this.fromPath, required this.toPath});

  final String fromPath;
  final String toPath;
}
