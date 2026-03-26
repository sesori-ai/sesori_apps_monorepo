import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";

import "daos/hidden_projects_dao.dart";
import "tables/hidden_projects.dart";

part "database.g.dart";

/// Central Drift database for the bridge CLI.
///
/// New tables and DAOs should be registered here as the persistence layer grows.
@DriftDatabase(tables: [HiddenProjects], daos: [HiddenProjectsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Creates the production database at `~/.local/share/sesori-bridge/sesori.db`.
  ///
  /// Uses [NativeDatabase.createInBackground] to run SQLite operations on a
  /// background isolate, appropriate for the long-running bridge process.
  static AppDatabase create() {
    final homeDir = Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"];
    if (homeDir == null) {
      throw StateError("Unable to determine home directory");
    }
    final dbDir = Directory("$homeDir/.local/share/sesori-bridge");
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final dbFile = File("${dbDir.path}/sesori.db");
    return AppDatabase(NativeDatabase.createInBackground(dbFile));
  }
}
