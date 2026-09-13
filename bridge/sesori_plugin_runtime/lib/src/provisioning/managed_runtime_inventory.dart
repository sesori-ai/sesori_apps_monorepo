import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "runtime_install_service.dart";
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

  /// Whether an outdated or incomplete pinned runtime should trigger
  /// installation of the bundled version.
  bool hasOutdatedVersion({required String stateDirectory}) {
    if (_hasCompletedBundledInstallation(stateDirectory: stateDirectory)) return false;

    final installed = installedVersions(stateDirectory: stateDirectory);
    return installed.isNotEmpty && installed.first.compareTo(_manifest.bundledVersion) <= 0;
  }

  bool _hasCompletedBundledInstallation({required String stateDirectory}) {
    final binary = File(
      _manifest.managedBinaryPath(stateDirectory: stateDirectory, version: _manifest.bundledVersion),
    );
    final sentinel = File(
      p.join(stateDirectory, _manifest.runtimeId, _manifest.bundledVersion.raw, RuntimeInstallService.sentinelFileName),
    );
    if (!binary.existsSync() || !sentinel.existsSync()) return false;
    try {
      return sentinel.readAsStringSync().trim().isNotEmpty;
    } on Object catch (error, stackTrace) {
      Log.w("[${_manifest.runtimeId}] managed runtime sentinel is unreadable", error, stackTrace);
      return false;
    }
  }
}
