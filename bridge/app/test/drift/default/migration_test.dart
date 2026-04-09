// dart format width=80
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sesori_bridge/src/bridge/persistence/database.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:sqlite3/sqlite3.dart';
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

  test('migration v4 → v5 structural validation', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(
      db,
      5,
      options: const ValidationOptions(validateDropped: true),
    );
    await db.close();
  });

  test('migration v4 → v5 preserves valid sessions and projects', () async {
    const oldProjectsTableData = [
      v4.ProjectsTableData(
        projectId: 'project-1',
        hidden: 0,
        baseBranch: 'main',
        worktreeCounter: 2,
      ),
      v4.ProjectsTableData(
        projectId: 'project-2',
        hidden: 1,
        baseBranch: null,
        worktreeCounter: 0,
      ),
    ];
    const oldSessionsTableData = [
      v4.SessionsTableData(
        sessionId: 'session-1',
        projectId: 'project-1',
        worktreePath: '/tmp/worktrees/session-1',
        branchName: 'feat/one',
        isDedicated: 1,
        archivedAt: null,
        baseBranch: 'main',
        baseCommit: 'abc123',
        createdAt: 1700000000000,
      ),
      v4.SessionsTableData(
        sessionId: 'session-2',
        projectId: 'project-1',
        worktreePath: null,
        branchName: null,
        isDedicated: 0,
        archivedAt: 1700000001000,
        baseBranch: null,
        baseCommit: null,
        createdAt: 1700000002000,
      ),
      v4.SessionsTableData(
        sessionId: 'session-3',
        projectId: 'project-2',
        worktreePath: '/tmp/worktrees/session-3',
        branchName: 'feat/two',
        isDedicated: 0,
        archivedAt: null,
        baseBranch: 'develop',
        baseCommit: 'def456',
        createdAt: 1700000003000,
      ),
      v4.SessionsTableData(
        sessionId: 'session-4',
        projectId: 'project-2',
        worktreePath: null,
        branchName: 'feat/three',
        isDedicated: 1,
        archivedAt: null,
        baseBranch: null,
        baseCommit: 'ghi789',
        createdAt: 1700000004000,
      ),
    ];
    const oldPullRequestsTableData = [
      v4.PullRequestsTableData(
        projectId: 'project-1',
        prNumber: 1,
        branchName: 'feat/one',
        url: 'https://example.com/pr/1',
        title: 'PR 1',
        state: 'OPEN',
        mergeableStatus: 'MERGEABLE',
        reviewDecision: 'APPROVED',
        checkStatus: 'SUCCESS',
        lastCheckedAt: 1700000005000,
        createdAt: 1700000006000,
      ),
      v4.PullRequestsTableData(
        projectId: 'project-2',
        prNumber: 2,
        branchName: 'feat/two',
        url: 'https://example.com/pr/2',
        title: 'PR 2',
        state: 'CLOSED',
        mergeableStatus: 'CONFLICTING',
        reviewDecision: 'CHANGES_REQUESTED',
        checkStatus: 'FAILURE',
        lastCheckedAt: 1700000007000,
        createdAt: 1700000008000,
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
        expect(
          await newDb.select(newDb.projectsTable).get(),
          unorderedEquals(const [
            v5.ProjectsTableData(
              projectId: 'project-1',
              hidden: 0,
              baseBranch: 'main',
              worktreeCounter: 2,
            ),
            v5.ProjectsTableData(
              projectId: 'project-2',
              hidden: 1,
              baseBranch: null,
              worktreeCounter: 0,
            ),
          ]),
        );
        expect(
          await newDb.select(newDb.sessionsTable).get(),
          unorderedEquals(const [
            v5.SessionsTableData(
              sessionId: 'session-1',
              projectId: 'project-1',
              worktreePath: '/tmp/worktrees/session-1',
              branchName: 'feat/one',
              isDedicated: 1,
              archivedAt: null,
              baseBranch: 'main',
              baseCommit: 'abc123',
              createdAt: 1700000000000,
            ),
            v5.SessionsTableData(
              sessionId: 'session-2',
              projectId: 'project-1',
              worktreePath: null,
              branchName: null,
              isDedicated: 0,
              archivedAt: 1700000001000,
              baseBranch: null,
              baseCommit: null,
              createdAt: 1700000002000,
            ),
            v5.SessionsTableData(
              sessionId: 'session-3',
              projectId: 'project-2',
              worktreePath: '/tmp/worktrees/session-3',
              branchName: 'feat/two',
              isDedicated: 0,
              archivedAt: null,
              baseBranch: 'develop',
              baseCommit: 'def456',
              createdAt: 1700000003000,
            ),
            v5.SessionsTableData(
              sessionId: 'session-4',
              projectId: 'project-2',
              worktreePath: null,
              branchName: 'feat/three',
              isDedicated: 1,
              archivedAt: null,
              baseBranch: null,
              baseCommit: 'ghi789',
              createdAt: 1700000004000,
            ),
          ]),
        );
        expect(
          await newDb.select(newDb.pullRequestsTable).get(),
          unorderedEquals(const [
            v5.PullRequestsTableData(
              projectId: 'project-1',
              prNumber: 1,
              branchName: 'feat/one',
              url: 'https://example.com/pr/1',
              title: 'PR 1',
              state: 'OPEN',
              mergeableStatus: 'MERGEABLE',
              reviewDecision: 'APPROVED',
              checkStatus: 'SUCCESS',
              lastCheckedAt: 1700000005000,
              createdAt: 1700000006000,
            ),
            v5.PullRequestsTableData(
              projectId: 'project-2',
              prNumber: 2,
              branchName: 'feat/two',
              url: 'https://example.com/pr/2',
              title: 'PR 2',
              state: 'CLOSED',
              mergeableStatus: 'CONFLICTING',
              reviewDecision: 'CHANGES_REQUESTED',
              checkStatus: 'FAILURE',
              lastCheckedAt: 1700000007000,
              createdAt: 1700000008000,
            ),
          ]),
        );
      },
    );
  });

  test(
    'migration v4 → v5 creates placeholder projects for orphan sessions',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.projectsTable, const [
            v4.ProjectsTableData(
              projectId: 'real',
              hidden: 0,
              baseBranch: 'main',
              worktreeCounter: 1,
            ),
          ]);
          batch.insertAll(oldDb.sessionsTable, const [
            v4.SessionsTableData(
              sessionId: 's1',
              projectId: 'real',
              worktreePath: null,
              branchName: null,
              isDedicated: 0,
              archivedAt: null,
              baseBranch: null,
              baseCommit: null,
              createdAt: 1000,
            ),
            v4.SessionsTableData(
              sessionId: 's2',
              projectId: 'ghost-1',
              worktreePath: null,
              branchName: null,
              isDedicated: 0,
              archivedAt: null,
              baseBranch: null,
              baseCommit: null,
              createdAt: 2000,
            ),
            v4.SessionsTableData(
              sessionId: 's3',
              projectId: 'ghost-2',
              worktreePath: null,
              branchName: null,
              isDedicated: 0,
              archivedAt: null,
              baseBranch: null,
              baseCommit: null,
              createdAt: 3000,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final projects = await newDb.select(newDb.projectsTable).get();
          expect(projects, hasLength(3));
          expect(
            projects,
            unorderedEquals(const [
              v5.ProjectsTableData(
                projectId: 'real',
                hidden: 0,
                baseBranch: 'main',
                worktreeCounter: 1,
              ),
              v5.ProjectsTableData(
                projectId: 'ghost-1',
                hidden: 0,
                baseBranch: null,
                worktreeCounter: 0,
              ),
              v5.ProjectsTableData(
                projectId: 'ghost-2',
                hidden: 0,
                baseBranch: null,
                worktreeCounter: 0,
              ),
            ]),
          );
          expect(await newDb.select(newDb.sessionsTable).get(), hasLength(3));
          expect(
            await newDb.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        },
      );
    },
  );

  test('migration v4 → v5 enforces FK on subsequent inserts', () async {
    final db = await _migrateFromV4(verifier: verifier);
    addTearDown(db.close);

    expect(
      () => db
          .into(db.sessionTable)
          .insert(
            SessionTableCompanion.insert(
              sessionId: 'test',
              projectId: 'nonexistent',
              isDedicated: false,
              createdAt: 0,
            ),
          ),
      throwsA(_isForeignKeyViolation),
    );
  });

  test(
    'migration v4 → v5 deleting a project cascades to sessions and PRs',
    () async {
      final db = await _migrateFromV4(verifier: verifier);
      addTearDown(db.close);

      await db
          .into(db.projectsTable)
          .insert(
            ProjectsTableCompanion.insert(projectId: 'p1'),
          );
      await db
          .into(db.sessionTable)
          .insert(
            SessionTableCompanion.insert(
              sessionId: 's1',
              projectId: 'p1',
              isDedicated: false,
              createdAt: 1000,
            ),
          );
      await db
          .into(db.sessionTable)
          .insert(
            SessionTableCompanion.insert(
              sessionId: 's2',
              projectId: 'p1',
              isDedicated: true,
              createdAt: 2000,
            ),
          );
      await db
          .into(db.pullRequestsTable)
          .insert(
            PullRequestsTableCompanion.insert(
              projectId: 'p1',
              prNumber: 1,
              branchName: 'feat/one',
              url: 'https://example.com/pr/1',
              title: 'PR 1',
              state: PrState.open,
              mergeableStatus: PrMergeableStatus.mergeable,
              reviewDecision: PrReviewDecision.approved,
              checkStatus: PrCheckStatus.success,
              lastCheckedAt: 3000,
              createdAt: 4000,
            ),
          );
      await db
          .into(db.pullRequestsTable)
          .insert(
            PullRequestsTableCompanion.insert(
              projectId: 'p1',
              prNumber: 2,
              branchName: 'feat/two',
              url: 'https://example.com/pr/2',
              title: 'PR 2',
              state: PrState.closed,
              mergeableStatus: PrMergeableStatus.conflicting,
              reviewDecision: PrReviewDecision.changesRequested,
              checkStatus: PrCheckStatus.failure,
              lastCheckedAt: 5000,
              createdAt: 6000,
            ),
          );

      await (db.delete(
        db.projectsTable,
      )..where((t) => t.projectId.equals('p1'))).go();

      expect(await db.select(db.projectsTable).get(), isEmpty);
      expect(await db.select(db.sessionTable).get(), isEmpty);
      expect(await db.select(db.pullRequestsTable).get(), isEmpty);
    },
  );
}

Future<AppDatabase> _migrateFromV4({required SchemaVerifier verifier}) async {
  final connection = await verifier.startAt(4);
  final db = AppDatabase(connection);
  await verifier.migrateAndValidate(
    db,
    5,
    options: const ValidationOptions(validateDropped: true),
  );
  return db;
}

final Matcher _isForeignKeyViolation = isA<SqliteException>().having(
  (exception) => exception.toString().toUpperCase(),
  'message',
  contains('FOREIGN KEY'),
);
