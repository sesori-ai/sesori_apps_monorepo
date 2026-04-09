import "dart:io";

import "package:sqlite3/sqlite3.dart";

/// Layer 1 API for direct SQLite operations on the OpenCode database.
///
/// This class performs raw PRAGMA and VACUUM operations on an external
/// SQLite database owned by OpenCode. It does not read or modify any
/// tables or data — only database-level maintenance commands.
class OpenCodeDbApi {
  /// Returns the current `auto_vacuum` mode.
  ///
  /// - `0` = NONE (default — no automatic vacuuming)
  /// - `1` = FULL (freed pages reclaimed after every DELETE)
  /// - `2` = INCREMENTAL (freed pages reclaimed on explicit request)
  ///
  /// Throws [SqliteException] if the database cannot be opened or queried.
  int getAutoVacuumMode({required String dbPath}) {
    final db = sqlite3.open(dbPath);
    try {
      final result = db.select("PRAGMA auto_vacuum");
      return result.first["auto_vacuum"] as int;
    } finally {
      db.close();
    }
  }

  /// Enables `auto_vacuum = FULL` and runs `VACUUM` to convert the database.
  ///
  /// After this one-time conversion, all future DELETE operations by OpenCode
  /// will automatically reclaim disk space.
  ///
  /// Returns `(sizeBefore, sizeAfter)` in bytes.
  ///
  /// Throws [SqliteException] with result code 5 (SQLITE_BUSY) if another
  /// process holds the database open.
  (int, int) enableAutoVacuumAndVacuum({required String dbPath}) {
    final sizeBefore = File(dbPath).lengthSync();
    final db = sqlite3.open(dbPath);
    try {
      db.execute("PRAGMA auto_vacuum = FULL");
      db.execute("VACUUM");
    } finally {
      db.close();
    }
    final sizeAfter = File(dbPath).lengthSync();
    return (sizeBefore, sizeAfter);
  }
}
