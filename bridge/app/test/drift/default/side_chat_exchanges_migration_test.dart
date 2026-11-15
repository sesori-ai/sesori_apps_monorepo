import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v24 to v25 adds an empty side chat table that follows its session", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(24);
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
    await verifier.migrateAndValidate(database, 25, options: const ValidationOptions(validateDropped: true));

    // Raw statements, so later versions changing the table class do not break this test.
    final empty = await database.customSelect("SELECT COUNT(*) AS n FROM side_chat_exchanges").getSingle();
    expect(empty.read<int>("n"), 0);
    await database.customStatement(
      "INSERT INTO side_chat_exchanges (id, session_id, side_chat_id, question, answer, asked_at, answered_at) "
      "VALUES ('x1', 's1', 'c1', 'q', 'a', 1, 2)",
    );
    await database.customStatement("DELETE FROM sessions_table WHERE session_id = 's1'");
    final afterDelete = await database.customSelect("SELECT COUNT(*) AS n FROM side_chat_exchanges").getSingle();
    expect(afterDelete.read<int>("n"), 0);
  });
}
