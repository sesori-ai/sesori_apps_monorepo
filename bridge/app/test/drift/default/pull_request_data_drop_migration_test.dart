import "dart:io";

import "package:drift_dev/api/migrations_native.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sqlite3/sqlite3.dart" show Database;
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v20 to v21 drops the stored PR data and keeps every project, session and worktree", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(20);
    final v20 = schema.rawDatabase;
    _insertRows(
      database: v20,
      table: "projects_table",
      rows: [
        {
          "project_id": "/work/app",
          "path": "/work/app",
          "hidden": 0,
          "base_branch": "main",
          "pr_cache_github_login": "octocat",
          "display_name": "App",
          "created_at": 100,
          "updated_at": 200,
          "projection_updated_at": 150,
        },
        {
          "project_id": "/work/lib",
          "path": "/work/lib",
          "hidden": 1,
          "base_branch": null,
          "pr_cache_github_login": null,
          "display_name": null,
          "created_at": 110,
          "updated_at": 210,
          "projection_updated_at": 160,
        },
      ],
    );
    _insertRows(
      database: v20,
      table: "sessions_table",
      rows: [
        _session(
          sessionId: "ses_root",
          projectId: "/work/app",
          parentSessionId: null,
          worktreePath: "/work/app/.worktrees/ses_root",
          branchName: "feature/stored",
          currentBranchName: "feature/live",
          archivedAt: null,
        ),
        _session(
          sessionId: "ses_child",
          projectId: "/work/app",
          parentSessionId: "ses_root",
          worktreePath: "/work/app/.worktrees/ses_root",
          branchName: null,
          currentBranchName: "feature/live",
          archivedAt: null,
        ),
        _session(
          sessionId: "ses_in_place",
          projectId: "/work/app",
          parentSessionId: null,
          worktreePath: null,
          branchName: null,
          currentBranchName: "main",
          archivedAt: null,
        ),
        _session(
          sessionId: "ses_archived",
          projectId: "/work/lib",
          parentSessionId: null,
          worktreePath: "/work/lib/.worktrees/ses_archived",
          branchName: "feature/old",
          currentBranchName: null,
          archivedAt: 400,
        ),
      ],
    );
    _insertRows(
      database: v20,
      table: "pull_requests_table",
      rows: [
        _pullRequest(projectId: "/work/app", prNumber: 7, branchName: "feature/live"),
        _pullRequest(projectId: "/work/app", prNumber: 8, branchName: "feature/stale"),
        _pullRequest(projectId: "/work/lib", prNumber: 9, branchName: "feature/old"),
      ],
    );
    // Rows in tables that reference the rebuilt tables: a rebuild that
    // cascaded would delete them.
    _insertRows(
      database: v20,
      table: "session_continuations",
      rows: [
        {"session_id": "ses_child", "enabled": 1, "outcome_json": '{"kind":"none"}'},
      ],
    );
    _insertRows(
      database: v20,
      table: "session_options_cache_table",
      rows: [
        {
          "plugin_id": "codex",
          "scope": "project",
          "owner_id": "/work/app",
          "project_id": "/work/app",
          "captured_project_path": "/work/app",
          "revision": 3,
          "captured_at": 100,
          "agents_json": '{"agents":[]}',
          "providers_json": '{"items":[],"connectedOnly":true}',
          "commands_json": '{"items":[]}',
        },
      ],
    );
    const keptTables = ["projects_table", "sessions_table", "session_continuations", "session_options_cache_table"];
    final before = {for (final table in keptTables) table: _rawRows(database: v20, table: table)};

    // Upgrade a database file through the bridge's own connection setup.
    final directory = await Directory.systemTemp.createTemp("sesori-v21-migration-");
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, "sesori.db"));
    v20.execute("VACUUM INTO ?", [file.path]);
    final database = AppDatabase.openFile(file: file);
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 21, options: const ValidationOptions(validateDropped: true));

    const droppedColumns = {"pr_cache_github_login", "current_branch_name", "current_github_repository_identity"};
    for (final table in keptTables) {
      final after = await database.customSelect("SELECT * FROM $table ORDER BY 1").get();
      expect(
        after.map((row) => row.data).toList(),
        [
          for (final row in before[table] ?? const <Map<String, Object?>>[])
            {
              for (final MapEntry(:key, :value) in row.entries)
                if (!droppedColumns.contains(key)) key: value,
            },
        ],
        reason: "$table keeps every row and every remaining value",
      );
    }

    final root = await database.sessionDao.getSession(sessionId: "ses_root");
    expect(root?.worktreePath, "/work/app/.worktrees/ses_root");
    expect(root?.branchName, "feature/stored");
    expect(root?.isDedicated, isTrue);
    expect((await database.sessionDao.getSession(sessionId: "ses_child"))?.parentSessionId, "ses_root");
    expect((await database.sessionDao.getSession(sessionId: "ses_archived"))?.branchName, "feature/old");
    expect(
      await database
          .customSelect(
            "SELECT name FROM sqlite_schema WHERE name IN ('pull_requests_table', 'idx_pull_requests_scope')",
          )
          .get(),
      isEmpty,
    );
    expect(await database.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });
}

void _insertRows({required Database database, required String table, required List<Map<String, Object?>> rows}) {
  for (final row in rows) {
    final columns = row.keys.join(", ");
    final placeholders = List.filled(row.length, "?").join(", ");
    database.execute("INSERT INTO $table ($columns) VALUES ($placeholders)", row.values.toList());
  }
}

List<Map<String, Object?>> _rawRows({required Database database, required String table}) {
  return [for (final row in database.select("SELECT * FROM $table ORDER BY 1")) Map<String, Object?>.of(row)];
}

Map<String, Object?> _session({
  required String sessionId,
  required String projectId,
  required String? parentSessionId,
  required String? worktreePath,
  required String? branchName,
  required String? currentBranchName,
  required int? archivedAt,
}) {
  return {
    "session_id": sessionId,
    "backend_session_id": "backend-$sessionId",
    "project_id": projectId,
    "parent_session_id": parentSessionId,
    "directory": worktreePath ?? projectId,
    "worktree_path": worktreePath,
    "branch_name": branchName,
    "current_branch_name": currentBranchName,
    "current_github_repository_identity": currentBranchName == null ? null : "sesori-ai/app",
    "is_dedicated": worktreePath != null && parentSessionId == null ? 1 : 0,
    "archived_at": archivedAt,
    "base_branch": "main",
    "base_commit": "abc123",
    "last_agent": "build",
    "last_agent_model": "anthropic|claude-sonnet|high",
    "fast_mode": 1,
    "created_at": 300,
    "updated_at": 350,
    "projection_updated_at": 340,
    "last_activity_at": 330,
    "last_seen_at": 320,
    "last_user_message_at": 310,
    "plugin_id": "codex",
    "title": "Title of $sessionId",
    "catalog_title": "Catalog title of $sessionId",
    "approval_override": "yolo",
  };
}

Map<String, Object?> _pullRequest({required String projectId, required int prNumber, required String branchName}) {
  return {
    "project_id": projectId,
    "github_repository_identity": "sesori-ai/app",
    "github_login": "octocat",
    "pr_number": prNumber,
    "branch_name": branchName,
    "url": "https://github.com/sesori-ai/app/pull/$prNumber",
    "title": "PR $prNumber",
    "state": "open",
    "mergeable_status": "mergeable",
    "review_decision": "approved",
    "check_status": "success",
    "last_checked_at": 500,
    "created_at": 450,
  };
}
