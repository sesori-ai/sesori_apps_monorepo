import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v23 to v24 leaves every session unpinned", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(23);
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
    await verifier.migrateAndValidate(database, 24, options: const ValidationOptions(validateDropped: true));

    // A raw read, so later versions adding columns do not break this test.
    final row = await database.customSelect("SELECT pinned FROM sessions_table WHERE session_id = 's1'").getSingle();
    expect(row.read<bool>("pinned"), isFalse);
  });
}
