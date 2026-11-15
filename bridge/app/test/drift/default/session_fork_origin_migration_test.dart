import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v25 to v26 leaves every session unforked, and deleting an origin nulls its forks' link", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(25);
    schema.rawDatabase.execute(
      "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?)",
      ["p1", "/projects/one", 0, 100, 200, 150],
    );
    for (final sessionId in ["s1", "s2"]) {
      schema.rawDatabase.execute(
        "INSERT INTO sessions_table (session_id, backend_session_id, project_id, directory, is_dedicated, "
        "created_at, updated_at, projection_updated_at, plugin_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [sessionId, "backend-$sessionId", "p1", "/projects/one", 0, 100, 200, 150, "codex"],
      );
    }

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 26, options: const ValidationOptions(validateDropped: true));

    // Raw reads and writes, so later versions adding columns do not break this test.
    final migrated = await database
        .customSelect("SELECT forked_from_session_id, forked_from_title FROM sessions_table ORDER BY session_id")
        .get();
    for (final row in migrated) {
      expect(row.read<String?>("forked_from_session_id"), isNull);
      expect(row.read<String?>("forked_from_title"), isNull);
    }

    await database.customStatement(
      "UPDATE sessions_table SET forked_from_session_id = 's1', forked_from_title = 'Origin' WHERE session_id = 's2'",
    );
    await database.customStatement("DELETE FROM sessions_table WHERE session_id = 's1'");
    final fork = await database
        .customSelect("SELECT forked_from_session_id, forked_from_title FROM sessions_table WHERE session_id = 's2'")
        .getSingle();
    expect(fork.read<String?>("forked_from_session_id"), isNull);
    expect(fork.read<String?>("forked_from_title"), "Origin");
  });
}
