import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v33 to v34 adds the command column and keeps existing tasks without one", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(33);
    schema.rawDatabase.execute(
      "INSERT INTO scheduled_tasks (id, name, prompt_json, project_id, plugin_id, fast_mode, dedicated_worktree, "
      "schedule_json, time_zone, missed_run_policy, run_mode, auto_compact, approval_mode, enabled, "
      "created_at, updated_at) "
      "VALUES ('t1', 'n', '{}', 'p1', 'codex', 0, 0, '{}', 'UTC', 'runWhenBack', 'newSession', 0, 'ask', 1, 1, 1)",
    );

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 34, options: const ValidationOptions(validateDropped: true));

    // A raw read, so later versions adding columns do not break this test.
    final task = await database.customSelect("SELECT name, command FROM scheduled_tasks").getSingle();
    expect(task.read<String>("name"), "n");
    expect(task.read<String?>("command"), isNull);
  });
}
