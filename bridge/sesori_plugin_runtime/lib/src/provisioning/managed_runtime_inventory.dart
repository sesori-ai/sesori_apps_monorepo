import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "runtime_manifest.dart";

/// Reports whether a managed runtime directory holds a version other than the
/// one currently pinned.
///
/// Managed runtimes are laid out as `<stateDirectory>/<runtimeId>/<version>/`,
/// so a bridge update that pins a newer version simply stops finding the old
/// one: setup reports the runtime as missing even though a previous version is
/// still on disk. Descriptors use this to tell the two cases apart — nothing
/// installed at all versus a superseded install — so the user is told the
/// runtime needs updating rather than being told to install it by hand.
///
/// Read-only: it never deletes or repairs anything. Sweeping superseded
/// versions remains [ManagedRuntimeCleaner]'s job during an install.
class ManagedRuntimeInventory {
  const ManagedRuntimeInventory({required RuntimeManifest manifest}) : _manifest = manifest;

  final RuntimeManifest _manifest;

  /// Whether a managed version directory other than the pinned
  /// [RuntimeManifest.bundledVersion] exists under [stateDirectory].
  ///
  /// Only the directory name is inspected; the binary inside is not probed,
  /// because this decides wording, not whether the runtime can run.
  bool hasSupersededVersion({required String stateDirectory}) {
    final managedDir = Directory(p.join(stateDirectory, _manifest.runtimeId));
    if (!managedDir.existsSync()) return false;

    final pinned = _manifest.bundledVersion.raw;
    try {
      return managedDir.listSync(followLinks: false).any(
        (entity) => entity is Directory && p.basename(entity.path) != pinned,
      );
    } on Object catch (error, stackTrace) {
      // Wording-only input: an unreadable directory falls back to the generic
      // hint rather than failing setup inspection.
      Log.w(
        "[${_manifest.runtimeId}] could not inspect managed runtime dir '${managedDir.path}'",
        error,
        stackTrace,
      );
      return false;
    }
  }
}
