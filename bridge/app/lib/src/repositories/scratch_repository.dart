import "dart:io" show FileSystemEntityType;

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../api/filesystem_api.dart";
import "project_catalog_identity_calculator.dart";

/// Owns the scratch root that project-less sessions run in: its "No project"
/// row, and the per-session folders with their removal with the session.
class ScratchRepository({
  required final FilesystemApi _filesystemApi,
  required final ProjectsDao _projectsDao,
  required final SessionDao _sessionDao,
  required final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator,
}) {
  /// Creates the scratch root, then inserts its visible "No project" row when
  /// it is missing. The row comes last, so a peer can only start a session in
  /// the root once the root exists. An existing row, renamed or not, is kept.
  ///
  /// A failure is logged and the bridge continues without "No project".
  Future<void> ensureScratchProject() async {
    final scratchRoot = _projectCatalogIdentityCalculator.scratchRoot;
    try {
      await _filesystemApi.createDirectoryRecursively(path: scratchRoot);
      await _projectsDao.insertProjectIfMissing(
        projectId: scratchRoot,
        path: scratchRoot,
        hidden: false,
        displayName: "No project",
      );
    } on Object catch (error, stackTrace) {
      Log.w("Could not set up the No project project in $scratchRoot; continuing without it", error, stackTrace);
    }
  }

  /// Creates a new `<YYYY-MM-DD>-<random>` folder in the scratch root, and the
  /// root first when it is missing, and returns the new folder's path.
  Future<String> createSessionDirectory() async {
    final scratchRoot = _projectCatalogIdentityCalculator.scratchRoot;
    await _filesystemApi.createDirectoryRecursively(path: scratchRoot);
    return await _filesystemApi.createTemporaryDirectory(
      parent: scratchRoot,
      prefix: "${_formatDate(date: clock.now())}-",
    );
  }

  /// Deletes the session folder at [path] and everything in it, but only when
  /// all of these hold:
  /// - [path] is a direct child of the scratch root, spelled without `..`;
  /// - no remaining session row has a directory at or under it;
  /// - it is a real directory and not a link.
  ///
  /// Otherwise the folder stays and the reason is logged. The removal never
  /// follows links inside the folder.
  Future<void> deleteSessionDirectoryIfUnused({required String path}) async {
    if (!_projectCatalogIdentityCalculator.isScratchSessionDirectory(path: path)) {
      Log.w(
        "Kept the folder of a deleted session because it is not a session folder in ${_projectCatalogIdentityCalculator.scratchRoot}: $path",
      );
      return;
    }
    final folder = normalizeProjectDirectory(directory: path);
    final storedDirectories = await _sessionDao.getAllSessionDirectories();
    if (storedDirectories.any((directory) => _isAtOrWithin(folder: folder, directory: directory))) {
      Log.d("Kept the folder of a deleted session because another session still uses it: $folder");
      return;
    }
    final type = _filesystemApi.entityType(folder);
    if (type == FileSystemEntityType.notFound) {
      Log.d("The folder of a deleted session was already gone: $folder");
      return;
    }
    if (type != FileSystemEntityType.directory) {
      Log.w("Kept the folder of a deleted session because it is a $type, not a directory: $folder");
      return;
    }
    await _filesystemApi.deleteDirectoryRecursivelyAsync(path: folder);
  }

  static bool _isAtOrWithin({required String folder, required String directory}) {
    final normalizedDirectory = normalizeProjectDirectory(directory: directory);
    return p.equals(folder, normalizedDirectory) || p.isWithin(folder, normalizedDirectory);
  }

  static String _formatDate({required DateTime date}) {
    final year = date.year.toString().padLeft(4, "0");
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }
}
