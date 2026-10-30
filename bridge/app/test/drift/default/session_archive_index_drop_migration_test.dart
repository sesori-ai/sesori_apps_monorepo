import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v21 to v22 drops the session archive index and keeps archived sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(21);
    schema.rawDatabase.execute(
      "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?)",
      ["p1", "/projects/one", 0, 100, 200, 150],
    );
    schema.rawDatabase.execute(
      "INSERT INTO sessions_table (session_id, backend_session_id, project_id, directory, is_dedicated, "
      "archived_at, created_at, updated_at, projection_updated_at, plugin_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      ["s1", "backend-s1", "p1", "/projects/one", 0, 300, 100, 200, 150, "codex"],
    );

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 22, options: const ValidationOptions(validateDropped: true));

    final archiveIndexes = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_sessions_archive'")
        .get();
    expect(archiveIndexes, isEmpty);
    expect((await database.sessionDao.getSession(sessionId: "s1"))?.archivedAt, 300);
  });
}
