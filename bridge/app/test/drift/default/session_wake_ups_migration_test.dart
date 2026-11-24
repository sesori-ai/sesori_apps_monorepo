import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v31 to v32 adds an empty wake-ups table that keeps existing sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(31);
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
    await verifier.migrateAndValidate(database, 32, options: const ValidationOptions(validateDropped: true));

    // Raw reads, so later versions adding columns do not break this test.
    final wakeUps = await database.customSelect("SELECT COUNT(*) AS c FROM session_wake_ups").getSingle();
    expect(wakeUps.read<int>("c"), 0);
    final sessions = await database.customSelect("SELECT COUNT(*) AS c FROM sessions_table").getSingle();
    expect(sessions.read<int>("c"), 1);
  });

  test("v32 to v33 adds the command columns and keeps existing wake-ups without one", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(32);
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
    schema.rawDatabase.execute(
      "INSERT INTO session_wake_ups (id, session_id, label, prompt, schedule_json, next_due_at, created_at) "
      "VALUES (?, ?, ?, ?, ?, ?, ?)",
      ["w1", "s1", "Check", "Look at CI", '{"type":"once"}', 300, 100],
    );

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 33, options: const ValidationOptions(validateDropped: true));

    final wakeUp = await database
        .customSelect("SELECT label, command, command_approval FROM session_wake_ups")
        .getSingle();
    expect(wakeUp.read<String>("label"), "Check");
    expect(wakeUp.read<String?>("command"), isNull);
    expect(wakeUp.read<String?>("command_approval"), isNull);
  });
}
