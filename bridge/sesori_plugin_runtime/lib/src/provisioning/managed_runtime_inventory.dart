import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "runtime_manifest.dart";
import "runtime_version.dart";

/// Reports which managed runtime versions are present on disk.
///
/// Managed runtimes are laid out as `<stateDirectory>/<runtimeId>/<version>/`,
/// so a bridge update that pins a newer version simply stops finding the old
/// one at the pinned path. Selection uses this to fall back to an older but
/// still supported version, and descriptors use it to tell "nothing installed"
/// apart from "superseded install" for wording and for the startup upgrade.
///
/// Read-only: it never deletes or repairs anything. Sweeping superseded
/// versions remains [ManagedRuntimeCleaner]'s job during an install.
class const ManagedRuntimeInventory({required final RuntimeManifest _manifest}) {
  /// Managed versions installed under [stateDirectory], newest first.
  ///
  /// Only directory names are inspected; no binary is probed. Names that do not
  /// parse as this runtime's version (installer staging, stray directories) are
  /// ignored, and an unreadable managed directory yields an empty list.
  List<RuntimeVersion> installedVersions({required String stateDirectory}) {
    final managedDir = Directory(p.join(stateDirectory, _manifest.runtimeId));
    if (!managedDir.existsSync()) return const [];

    final List<FileSystemEntity> entries;
    try {
      entries = managedDir.listSync(followLinks: false);
    } on Object catch (error, stackTrace) {
      // Advisory input: an unreadable directory reads as "nothing managed here"
      // rather than failing setup inspection or an install.
      Log.w(
        "[${_manifest.runtimeId}] could not inspect managed runtime dir '${managedDir.path}'",
        error,
        stackTrace,
      );
      return const [];
    }

    final versions = [
      for (final entity in entries)
        if (entity is Directory) ?_manifest.parseInstalledVersion(value: p.basename(entity.path)),
    ];
    versions.sort((a, b) => b.compareTo(a));
    return List<RuntimeVersion>.unmodifiable(versions);
  }

  /// Whether a managed version directory other than the pinned
  /// [RuntimeManifest.bundledVersion] exists under [stateDirectory].
  bool hasSupersededVersion({required String stateDirectory}) {
    final pinned = _manifest.bundledVersion.raw;
    return installedVersions(stateDirectory: stateDirectory).any((version) => version.raw != pinned);
  }
}
