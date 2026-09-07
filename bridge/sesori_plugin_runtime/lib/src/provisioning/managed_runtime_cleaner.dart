import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Removes managed runtime version directories the caller no longer wants.
///
/// A managed runtime is laid out as `<managedDir>/<version>/<binary>`. Older
/// version directories are dead weight from a previous bridge release's bundled
/// runtime, but which ones are safe to remove depends on where the install is:
/// an obsolete version can go before the download starts, while a still-usable
/// one must survive until its replacement is verified and no generation runs
/// from it. The caller owns that decision through [keep].
class ManagedRuntimeCleaner({required final String _runtimeId}) {
  /// Deletes every immediate subdirectory of [managedDir] that [keep] rejects.
  /// Best-effort: a directory that cannot be removed is logged and skipped.
  Future<void> sweep({
    required String managedDir,
    required bool Function({required String versionName}) keep,
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
      if (keep(versionName: name)) {
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
