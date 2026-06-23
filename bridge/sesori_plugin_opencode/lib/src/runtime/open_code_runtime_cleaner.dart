import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Removes superseded managed OpenCode runtime version directories.
///
/// The managed runtime is laid out as `<managedDir>/<version>/opencode`. After
/// the pinned version is healthy, older version directories are dead weight from
/// a previous bridge release's bundled runtime; this sweeps them, keeping only
/// the version currently in use so a running runtime is never deleted.
class OpenCodeRuntimeCleaner {
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

    for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final String name = p.basename(entity.path);
      if (name == keepVersion) {
        continue;
      }
      try {
        entity.deleteSync(recursive: true);
        Log.d("[opencode] removed superseded managed runtime '$name'");
      } on Object catch (error) {
        Log.w("[opencode] failed to remove superseded managed runtime '$name': $error");
      }
    }
  }
}
