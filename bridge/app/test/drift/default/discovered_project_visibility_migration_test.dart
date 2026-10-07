import "dart:io";

import "package:drift_dev/api/migrations_native.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v19 to v20 shows hidden projects that today's discovery rule shows", () async {
    final home = resolveUserHomeDirectory(environment: Platform.environment);
    if (home == null) fail("test host has no user home directory");
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(19);
    final rows = {
      "ordinary-hidden": ("/work/app", 1),
      "ordinary-visible": ("/work/other", 0),
      "temporary": ("/tmp/scratch", 1),
      "home-dot": (p.join(home, ".cache", "tool"), 1),
    };
    for (final MapEntry(key: projectId, value: (path, hidden)) in rows.entries) {
      schema.rawDatabase.execute(
        "INSERT INTO projects_table (project_id, path, hidden, created_at, updated_at, projection_updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        [projectId, path, hidden, 100, 200, 150],
      );
    }

    final database = AppDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 20, options: const ValidationOptions(validateDropped: true));

    final projects = await database.projectsDao.getAllProjects();
    expect(
      {for (final project in projects) project.projectId: project.hidden},
      {"ordinary-hidden": false, "ordinary-visible": false, "temporary": true, "home-dot": true},
    );
  });
}
