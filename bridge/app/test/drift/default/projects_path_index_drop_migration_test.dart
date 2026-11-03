import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v22 to v23 drops the projects path index and keeps projects", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(22);
    schema.rawDatabase.execute(
      "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
      "VALUES (?, ?, ?, ?, ?, ?)",
      ["p1", "/projects/one", 0, 100, 200, 150],
    );

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 23, options: const ValidationOptions(validateDropped: true));

    final pathIndexes = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_projects_path'")
        .get();
    expect(pathIndexes, isEmpty);
    expect((await database.projectsDao.getProject(projectId: "p1"))?.path, "/projects/one");
  });
}
