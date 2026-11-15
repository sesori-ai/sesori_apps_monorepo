import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v25 to v26 adds task tables and a task link that deleting the task clears", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(25);
    schema.rawDatabase.execute(
      "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?)",
      ["p1", "/projects/one", 0, 100, 200, 150],
    );
    schema.rawDatabase.execute(
      "INSERT INTO sessions_table (session_id, backend_session_id, project_id, directory, is_dedicated, "
      "created_at, updated_at, projection_updated_at, plugin_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      ["s1", "backend-s1", "p1", "/projects/one", 0, 100, 200, 150, "codex"],
    );

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 26, options: const ValidationOptions(validateDropped: true));

    // Raw statements, so later versions changing the table classes do not break this test.
    Future<Object?> scalar(String sql) async => (await database.customSelect(sql).getSingle()).data.values.single;
    expect(await scalar("SELECT scheduled_task_id FROM sessions_table WHERE session_id = 's1'"), isNull);

    await database.customStatement(
      "INSERT INTO scheduled_tasks (id, name, prompt_json, project_id, plugin_id, fast_mode, dedicated_worktree, "
      "schedule_json, time_zone, missed_run_policy, run_mode, auto_compact, approval_mode, enabled, "
      "target_session_id, created_at, updated_at) "
      "VALUES ('t1', 'n', '{}', 'p1', 'codex', 0, 0, '{}', 'UTC', 'runWhenBack', 'sameSession', 0, 'ask', 1, "
      "'s1', 1, 1)",
    );
    await database.customStatement("UPDATE sessions_table SET scheduled_task_id = 't1' WHERE session_id = 's1'");
    await database.customStatement(
      "INSERT INTO scheduled_task_runs (id, task_id, session_id, scheduled_for, scheduled_for_offset_minutes, "
      "fired_at, outcome, late) VALUES ('r1', 't1', 's1', 1, 0, 1, 'started', 0)",
    );

    await database.customStatement("DELETE FROM scheduled_tasks WHERE id = 't1'");
    expect(await scalar("SELECT COUNT(*) FROM scheduled_task_runs"), 0);
    expect(await scalar("SELECT scheduled_task_id FROM sessions_table WHERE session_id = 's1'"), isNull);
  });
}
