import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Removes superseded managed runtime version directories.
///
/// A managed runtime is laid out as `<managedDir>/<version>/<binary>`. After the
/// pinned version is healthy, older version directories are dead weight from a
/// previous bridge release's bundled runtime; this sweeps them, keeping only the
/// version currently in use so a running runtime is never deleted.
class ManagedRuntimeCleaner {
  ManagedRuntimeCleaner({required String runtimeId}) : _runtimeId = runtimeId;

  final String _runtimeId;

  /// Deletes every immediate subdirectory of [managedDir] except [keepVersion].
  /// Best-effort: a directory that cannot be removed is logged and skipped.
  Future<void> sweep({
    required String managedDir,
    required String keepVersion,
  }) async {
    final Directory dir = Directory(managedDir);
    if (!dir.existsSync()) {
      return;
    }

    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on Object catch (error, stackTrace) {
      // Best-effort cleanup: a permission/IO error listing the managed dir must
      // not propagate (this runs after the runtime is already healthy).
      Log.w("[$_runtimeId] failed to list managed runtime dir '$managedDir'", error, stackTrace);
      return;
    }

    for (final FileSystemEntity entity in entries) {
      if (entity is! Directory) {
        continue;
      }
      final String name = p.basename(entity.path);
      if (name == keepVersion) {
        continue;
      }
      try {
        entity.deleteSync(recursive: true);
        Log.d("[$_runtimeId] removed superseded managed runtime '$name'");
      } on Object catch (error, stackTrace) {
        Log.w("[$_runtimeId] failed to remove superseded managed runtime '$name'", error, stackTrace);
      }
    }
  }
}
