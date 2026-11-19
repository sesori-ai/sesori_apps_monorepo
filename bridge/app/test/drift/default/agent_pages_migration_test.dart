import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v30 to v31 adds an empty agent pages table that keeps existing sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(30);
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
    await verifier.migrateAndValidate(database, 31, options: const ValidationOptions(validateDropped: true));

    // Raw reads, so later versions adding columns do not break this test.
    final pages = await database.customSelect("SELECT COUNT(*) AS c FROM agent_pages").getSingle();
    expect(pages.read<int>("c"), 0);
    final sessions = await database.customSelect("SELECT COUNT(*) AS c FROM sessions_table").getSingle();
    expect(sessions.read<int>("c"), 1);
  });
}
