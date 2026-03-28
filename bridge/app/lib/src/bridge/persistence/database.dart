import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";

import "daos/projects_dao.dart";
import "daos/session_worktrees_dao.dart";
import "database.steps.dart";
import "tables/projects_table.dart";
import "tables/session_worktrees_table.dart";

part "database.g.dart";

/// Central Drift database for the bridge CLI.
///
/// New tables and DAOs should be registered here as the persistence layer grows.
@DriftDatabase(tables: [ProjectsTable, SessionWorktreesTable], daos: [ProjectsDao, SessionWorktreesDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.projectsTable, schema.projectsTable.baseBranch);
        await m.addColumn(schema.projectsTable, schema.projectsTable.worktreeCounter);
        await m.createTable(schema.sessionWorktreesTable);
      },
    ),
    beforeOpen: (details) async {
      await customStatement("PRAGMA foreign_keys = ON");
    },
  );

  /// Creates the production database at `~/.config/sesori-bridge/sesori.db`.
  ///
  /// Uses [NativeDatabase.createInBackground] to run SQLite operations on a
  /// background isolate, appropriate for the long-running bridge process.
  static AppDatabase create() {
    final homeDir = Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"];
    if (homeDir == null) {
      throw StateError("Unable to determine home directory");
    }
    final dbDir = Directory("$homeDir/.config/sesori-bridge");
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final dbFile = File("${dbDir.path}/sesori.db");
    return AppDatabase(NativeDatabase.createInBackground(dbFile));
  }
}
