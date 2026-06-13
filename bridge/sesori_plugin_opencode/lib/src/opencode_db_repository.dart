import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sqlite3/sqlite3.dart";

import "opencode_db_api.dart";

/// Layer 2 Repository wrapping [OpenCodeDbApi].
///
/// Translates raw SQLite results and exceptions into domain-level
/// values that the service layer can consume without knowing about
/// the underlying database implementation.
class OpenCodeDbRepository {
  final OpenCodeDbApi _api;

  OpenCodeDbRepository({required OpenCodeDbApi api}) : _api = api;

  /// Returns the current auto_vacuum mode, or `null` if the database
  /// file does not exist or cannot be read.
  Future<int?> getAutoVacuumMode({required String dbPath}) async {
    if (!File(dbPath).existsSync()) {
      Log.d("OpenCode database not found — skipping");
      return null;
    }

    try {
      return await _api.getAutoVacuumMode(dbPath: dbPath);
    } on SqliteException catch (e) {
      _logError(error: e);
      return null;
    }
  }

  /// Returns the database file size in bytes, or `0` if the file
  /// does not exist.
  int getDbSizeBytes({required String dbPath}) {
    final file = File(dbPath);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  /// Enables auto_vacuum=FULL and runs VACUUM.
  ///
  /// Returns `(sizeBefore, sizeAfter)` in bytes on success, or `null`
  /// if the operation failed (database locked, corrupted, etc.).
  Future<(int, int)?> enableAutoVacuumAndVacuum({required String dbPath}) async {
    try {
      return await _api.enableAutoVacuumAndVacuum(dbPath: dbPath);
    } on SqliteException catch (e) {
      _logError(error: e);
      return null;
    } on Object catch (e) {
      Log.w("Database optimization failed: $e");
      return null;
    }
  }

  void _logError({required SqliteException error}) {
    if (error.resultCode == 5 /* SQLITE_BUSY */ ) {
      Log.d(
        "OpenCode database is in use — "
        "will retry next startup",
      );
    } else {
      Log.w("Database optimization failed: $error");
    }
  }
}
