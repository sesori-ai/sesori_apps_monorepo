import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_shared/sesori_shared.dart" show SessionApprovalMode;
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v18 to v19 leaves every session following the bridge YOLO setting", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(18);
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
    await verifier.migrateAndValidate(database, 19, options: const ValidationOptions(validateDropped: true));

    expect((await database.sessionDao.getSession(sessionId: "s1"))?.approvalOverride, isNull);
    expect(await database.sessionDao.hasApprovalOverride(approvalOverride: SessionApprovalMode.yolo), isFalse);
  });
}
