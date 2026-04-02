// dart format width=80
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sesori_bridge/src/bridge/persistence/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

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

  test('migrates schema from v3 to v4', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('migration from v3 to v4 preserves existing data', () async {
    const oldProjectsTableData = [
      v3.ProjectsTableData(
        projectId: 'project-1',
        hidden: 0,
        baseBranch: 'main',
        worktreeCounter: 2,
      ),
    ];
    const oldSessionsTableData = [
      v3.SessionsTableData(
        sessionId: 'session-1',
        projectId: 'project-1',
        worktreePath: '/tmp/worktrees/session-1',
        branchName: 'feat/test',
        isDedicated: 1,
        archivedAt: null,
        baseBranch: 'main',
        baseCommit: 'abc123',
        createdAt: 1700000000000,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
        batch.insertAll(oldDb.sessionsTable, oldSessionsTableData);
      },
      validateItems: (newDb) async {
        final projects = await newDb.select(newDb.projectsTable).get();
        expect(projects, hasLength(1));
        expect(projects.single.projectId, equals('project-1'));
        expect(projects.single.hidden, equals(0));
        expect(projects.single.baseBranch, equals('main'));
        expect(projects.single.worktreeCounter, equals(2));

        final sessions = await newDb.select(newDb.sessionsTable).get();
        expect(sessions, hasLength(1));
        expect(sessions.single.sessionId, equals('session-1'));
        expect(sessions.single.projectId, equals('project-1'));
        expect(
          sessions.single.worktreePath,
          equals('/tmp/worktrees/session-1'),
        );
        expect(sessions.single.branchName, equals('feat/test'));
        expect(sessions.single.isDedicated, equals(1));
        expect(sessions.single.archivedAt, isNull);
        expect(sessions.single.baseBranch, equals('main'));
        expect(sessions.single.baseCommit, equals('abc123'));
        expect(sessions.single.createdAt, equals(1700000000000));

        expect(await newDb.select(newDb.pullRequestsTable).get(), isEmpty);
      },
    );
  });

  test('migrates schema from v4 to v5', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  test(
    'migration from v4 to v5 preserves data and cascades session deletion',
    () async {
      const oldProjectsTableData = [
        v4.ProjectsTableData(
          projectId: 'project-1',
          hidden: 0,
          baseBranch: 'main',
          worktreeCounter: 2,
        ),
      ];
      const oldSessionsTableData = [
        v4.SessionsTableData(
          sessionId: 'session-1',
          projectId: 'project-1',
          worktreePath: '/tmp/worktrees/session-1',
          branchName: 'feat/test',
          isDedicated: 1,
          archivedAt: null,
          baseBranch: 'main',
          baseCommit: 'abc123',
          createdAt: 1700000000000,
        ),
      ];
      const oldPullRequestsTableData = [
        v4.PullRequestsTableData(
          projectId: 'project-1',
          branchName: 'feat/test',
          prNumber: 11,
          url: 'https://github.com/org/repo/pull/11',
          title: 'Add migration coverage',
          state: 'OPEN',
          mergeableStatus: 'MERGEABLE',
          reviewDecision: null,
          checkStatus: 'SUCCESS',
          sessionId: 'session-1',
          lastCheckedAt: 1700000001000,
          createdAt: 1700000000000,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
          batch.insertAll(oldDb.sessionsTable, oldSessionsTableData);
          batch.insertAll(oldDb.pullRequestsTable, oldPullRequestsTableData);
        },
        validateItems: (newDb) async {
          final projects = await newDb.select(newDb.projectsTable).get();
          expect(projects, hasLength(1));
          expect(projects.single.projectId, equals('project-1'));

          final sessions = await newDb.select(newDb.sessionsTable).get();
          expect(sessions, hasLength(1));
          expect(sessions.single.sessionId, equals('session-1'));

          final prsBeforeDelete = await newDb
              .select(newDb.pullRequestsTable)
              .get();
          expect(prsBeforeDelete, hasLength(1));
          expect(prsBeforeDelete.single.sessionId, equals('session-1'));

          await (newDb.delete(
            newDb.sessionsTable,
          )..where((t) => t.sessionId.equals('session-1'))).go();

          final sessionsAfterDelete = await newDb
              .select(newDb.sessionsTable)
              .get();
          expect(sessionsAfterDelete, isEmpty);
          final prsAfterDelete = await newDb
              .select(newDb.pullRequestsTable)
              .get();
          expect(prsAfterDelete, isEmpty);
        },
      );
    },
  );
}
