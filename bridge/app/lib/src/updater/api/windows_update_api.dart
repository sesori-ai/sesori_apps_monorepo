import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_update_api.dart';

/// Windows in-place update applier.
///
/// Windows lets a *loaded* `.exe`/`.dll` file be renamed but not deleted, and
/// it forbids renaming a directory that contains a loaded DLL. So the binary is
/// renamed aside to `.sesori-bridge.old` and `lib/` is swapped **per file**
/// (each current file renamed into `.lib.old/`, each staged file renamed in).
/// The displaced `.old` artifacts cannot be deleted while this process holds
/// them open, so they are swept on the next launch.
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
        _move(performed: performed, from: targetBinary, toPath: backupBinary.path, isDirectory: false);
      }
      _move(performed: performed, from: newBinary, toPath: targetBinary.path, isDirectory: false);

      // Displace the currently-installed lib files (loaded DLLs can be renamed).
      for (final FileSystemEntity entity in targetLibDir.listSync()) {
        final bool isDirectory = entity is Directory;
        _move(
          performed: performed,
          from: entity,
          toPath: p.join(backupLibDir.path, p.basename(entity.path)),
          isDirectory: isDirectory,
        );
      }
      // Move the staged lib files into place.
      for (final FileSystemEntity entity in newLibDir.listSync()) {
        final bool isDirectory = entity is Directory;
        _move(
          performed: performed,
          from: entity,
          toPath: p.join(targetLibDir.path, p.basename(entity.path)),
          isDirectory: isDirectory,
        );
      }
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

  void _move({
    required List<_Move> performed,
    required FileSystemEntity from,
    required String toPath,
    required bool isDirectory,
  }) {
    from.renameSync(toPath);
    performed.add(_Move(fromPath: from.path, toPath: toPath, isDirectory: isDirectory));
  }

  void _rollback({required List<_Move> performed}) {
    for (final _Move move in performed.reversed) {
      try {
        final FileSystemEntity moved = move.isDirectory ? Directory(move.toPath) : File(move.toPath);
        if (moved.existsSync()) {
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

/// A single rename performed during an apply, recorded so it can be reversed if
/// a later step fails.
class _Move {
  const _Move({
    required this.fromPath,
    required this.toPath,
    required this.isDirectory,
  });

  final String fromPath;
  final String toPath;
  final bool isDirectory;
}
