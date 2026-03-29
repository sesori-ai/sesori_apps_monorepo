// dart format width=80
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sesori_bridge/src/bridge/persistence/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates schema from v2 to v3', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('migrates schema from v1 to v3', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 3);
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

  test(
    'migration from v2 to v3 rebuilds sessions table and preserves data',
    () async {
      final oldSessionData = <v2.SessionWorktreesTableData>[
        const v2.SessionWorktreesTableData(
          sessionId: 'session-1',
          projectId: 'project-1',
          worktreePath: '/tmp/worktrees/session-1',
          branchName: 'session-001',
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.sessionWorktreesTable, oldSessionData);
        },
        validateItems: (newDb) async {
          final sessions = await newDb.select(newDb.sessionsTable).get();
          expect(sessions, hasLength(1));

          final migrated = sessions.single;
          expect(migrated.sessionId, equals('session-1'));
          expect(migrated.projectId, equals('project-1'));
          expect(migrated.worktreePath, equals('/tmp/worktrees/session-1'));
          expect(migrated.branchName, equals('session-001'));
          expect(migrated.isDedicated, equals(1));
          expect(migrated.archivedAt, isNull);
          expect(migrated.baseBranch, isNull);
          expect(migrated.baseCommit, isNull);
          expect(migrated.createdAt, greaterThan(0));
        },
      );
    },
  );
}
