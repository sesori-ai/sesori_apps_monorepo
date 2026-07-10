import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/pull_request_dao.dart";
import "../api/database/tables/pull_requests_table.dart";
import "daos/projects_dao.dart";
import "daos/session_dao.dart";
import "database.steps.dart";
import "tables/deleted_sessions_table.dart";
import "tables/projects_table.dart";
import "tables/session_table.dart";

part "database.g.dart";

/// Central Drift database for the bridge CLI.
///
/// New tables and DAOs should be registered here as the persistence layer grows.
@DriftDatabase(
  tables: [ProjectsTable, SessionTable, DeletedSessionsTable, PullRequestsTable],
  daos: [ProjectsDao, SessionDao, PullRequestDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

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
      from4To5: (m, schema) async {
        // Seed placeholder projects before recreating the sessions table with
        // an FK. Existing orphan sessions must be preserved, not deleted.
        await m.database.customStatement(
          'INSERT OR IGNORE INTO projects_table '
          '(project_id, hidden, base_branch, worktree_counter) '
          'SELECT DISTINCT project_id, 0, NULL, 0 FROM sessions_table '
          'WHERE project_id NOT IN '
          '(SELECT project_id FROM projects_table)',
        );

        // Drift recreates the table to add the FK while preserving the
        // WITHOUT ROWID table shape.
        await m.alterTable(TableMigration(schema.sessionsTable));

        // Migrations run inside a transaction, so foreign_keys cannot be
        // toggled mid-flight. Validate the final graph explicitly instead.
        final violations = await m.database.customSelect('PRAGMA foreign_key_check').get();
        if (violations.isNotEmpty) {
          throw StateError(
            'Migration v4→v5 failed: ${violations.length} FK violations '
            'remain after orphan cleanup. Rows: '
            '${violations.map((row) => row.data).toList()}',
          );
        }
      },
      from5To6: (m, schema) async {
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.lastAgent);
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.lastAgentModel);
      },
      from6To7: (m, schema) async {
        // Unseen-changes tracking. All three columns are nullable and default
        // to NULL, which the unseen calculator treats as 0 — so every existing
        // session is baseline-"seen" (unseen = activity > max(userMessage,
        // seen) == 0 > 0 == false) until new activity arrives.
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.lastActivityAt);
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.lastSeenAt);
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.lastUserMessageAt);
      },
      from7To8: (m, schema) async {
        // Bridge-owned project metadata for derive-style plugins. Every project
        // id ever persisted has been the project's directory path, so `path`
        // backfills straight from it; `openedAt` is backfilled with the
        // migration wall-clock time (the best "recorded at" we have for rows
        // that predate the column).
        await m.alterTable(
          TableMigration(
            schema.projectsTable,
            newColumns: [
              schema.projectsTable.path,
              schema.projectsTable.displayName,
              schema.projectsTable.openedAt,
            ],
            columnTransformer: {
              schema.projectsTable.path: schema.projectsTable.projectId,
              schema.projectsTable.openedAt: Constant<int>(DateTime.now().millisecondsSinceEpoch),
            },
          ),
        );
        // Backfill every pre-existing session row to opencode — the only
        // plugin shipped before pluginId existed. This migration is the single
        // place the persistence layer is allowed to know opencode's id; the
        // column itself has no default and every insert stamps the active
        // plugin's id explicitly.
        await m.alterTable(
          TableMigration(
            schema.sessionsTable,
            newColumns: [schema.sessionsTable.pluginId],
            columnTransformer: {
              schema.sessionsTable.pluginId: const Constant<String>("opencode"),
            },
          ),
        );
      },
      from8To9: (m, schema) async {
        // Bridge-owned title for derive-plugin sessions (their backends don't
        // persist renames). Existing rows have no bridge-known title.
        await m.addColumn(schema.sessionsTable, schema.sessionsTable.title);
        // Tombstones for deleted derive-plugin sessions, so a backend without
        // session deletion can't resurrect them through enumeration.
        await m.createTable(schema.deletedSessionsTable);
      },
    ),
    beforeOpen: (details) async {
      await customStatement("PRAGMA foreign_keys = ON");
    },
  );

  static AppDatabase create() {
    final dbDir = Directory(sesoriDataDirectory());
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final dbFile = File("${dbDir.path}/sesori.db");
    return AppDatabase(NativeDatabase.createInBackground(dbFile));
  }
}
