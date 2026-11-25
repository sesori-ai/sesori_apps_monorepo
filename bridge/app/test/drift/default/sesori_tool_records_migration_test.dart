import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v34 to v35 adds the empty tool-record tables and keeps existing sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(34);
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
    await verifier.migrateAndValidate(database, 35, options: const ValidationOptions(validateDropped: true));

    // Raw reads, so later versions adding columns do not break this test.
    for (final table in ["sesori_tool_session_records", "sesori_tool_records"]) {
      final rows = await database.customSelect("SELECT COUNT(*) AS c FROM $table").getSingle();
      expect(rows.read<int>("c"), 0, reason: table);
    }
    final sessions = await database.customSelect("SELECT COUNT(*) AS c FROM sessions_table").getSingle();
    expect(sessions.read<int>("c"), 1);
  });
}
