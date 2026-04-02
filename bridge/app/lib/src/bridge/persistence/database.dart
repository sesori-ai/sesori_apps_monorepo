import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";

import "daos/projects_dao.dart";
import "daos/session_dao.dart";
import "database.steps.dart";
import "tables/pull_requests_table.dart";
import "tables/projects_table.dart";
import "tables/session_table.dart";

part "database.g.dart";

/// Central Drift database for the bridge CLI.
///
/// New tables and DAOs should be registered here as the persistence layer grows.
@DriftDatabase(
  tables: [ProjectsTable, SessionTable, PullRequestsTable],
  daos: [ProjectsDao, SessionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.projectsTable, schema.projectsTable.baseBranch);
        await m.addColumn(schema.projectsTable, schema.projectsTable.worktreeCounter);
        await m.createTable(schema.sessionWorktreesTable);
      },
      from2To3: (m, schema) async {
        await customStatement("""
          CREATE TABLE sessions_table (
            session_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            worktree_path TEXT NULL,
            branch_name TEXT NULL,
            is_dedicated INTEGER NOT NULL CHECK (is_dedicated IN (0, 1)),
            archived_at INTEGER NULL,
            base_branch TEXT NULL,
            base_commit TEXT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (session_id)
          ) WITHOUT ROWID
        """);

        await customStatement("""
          INSERT INTO sessions_table (
            session_id,
            project_id,
            worktree_path,
            branch_name,
            is_dedicated,
            archived_at,
            base_branch,
            base_commit,
            created_at
          )
          SELECT
            session_id,
            project_id,
            worktree_path,
            branch_name,
            1 AS is_dedicated,
            NULL AS archived_at,
            NULL AS base_branch,
            NULL AS base_commit,
            CAST(strftime('%s', 'now') AS INTEGER) * 1000 AS created_at
          FROM session_worktrees_table
        """);

        await customStatement("DROP TABLE session_worktrees_table");
      },
      from3To4: (m, schema) async {
        await m.createTable(schema.pullRequestsTable);
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
