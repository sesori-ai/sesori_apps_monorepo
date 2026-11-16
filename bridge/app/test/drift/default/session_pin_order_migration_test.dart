import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v28 to v29 keeps the pinned sessions in the order they showed and leaves the rest unpinned", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(28);
    schema.rawDatabase.execute(
      "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?)",
      ["p1", "/projects/one", 0, 100, 200, 150],
    );
    for (final (id, updatedAt, userMessageAt, pinned) in [
      ("recent-pin", 300, null, 1),
      // Shown by its newer user message.
      ("messaged-pin", 100, 500, 1),
      ("old-pin", 200, null, 1),
      ("unpinned", 900, null, 0),
    ]) {
      schema.rawDatabase.execute(
        "INSERT INTO sessions_table (session_id, backend_session_id, project_id, directory, is_dedicated, "
        "created_at, updated_at, projection_updated_at, plugin_id, last_user_message_at, pinned) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [id, "backend-$id", "p1", "/projects/one", 0, 100, updatedAt, 150, "codex", userMessageAt, pinned],
      );
    }

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 29, options: const ValidationOptions(validateDropped: true));

    // A raw read, so later versions adding columns do not break this test.
    final rows = await database
        .customSelect("SELECT session_id, pin_order FROM sessions_table ORDER BY pin_order DESC, session_id")
        .get();
    expect(
      [for (final row in rows) (row.read<String>("session_id"), row.read<int?>("pin_order"))],
      [("messaged-pin", 500), ("recent-pin", 300), ("old-pin", 200), ("unpinned", null)],
    );
  });
}
