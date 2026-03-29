// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sesori_bridge/src/bridge/persistence/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates schema from v1 to v2', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('migration from v1 to v2 preserves project data and defaults', () async {
    final oldProjectsTableData = <v1.ProjectsTableData>[
      const v1.ProjectsTableData(projectId: 'project-1', hidden: 1),
    ];
    final expectedNewProjectsTableData = <v2.ProjectsTableData>[
      const v2.ProjectsTableData(
        projectId: 'project-1',
        hidden: 1,
        baseBranch: null,
        worktreeCounter: 0,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
      },
      validateItems: (newDb) async {
        expect(
          await newDb.select(newDb.projectsTable).get(),
          expectedNewProjectsTableData,
        );
        expect(await newDb.select(newDb.sessionWorktreesTable).get(), isEmpty);
      },
    );
  });
}
