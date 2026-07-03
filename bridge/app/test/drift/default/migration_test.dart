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
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;

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

  test('the v5 session→project FK stays enforced on the current schema', () async {
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
              pluginId: 'opencode',
            ),
          ),
      throwsA(_isForeignKeyViolation),
    );
  });

  test('migration v5 → v6 structural validation', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 6);
    await db.close();
  });

  test(
    'migration v5 → v6 preserves sessions and defaults new fields to null',
    () async {
      const oldProjectsTableData = [
        v5.ProjectsTableData(
          projectId: 'project-1',
          hidden: 0,
          baseBranch: 'main',
          worktreeCounter: 2,
        ),
      ];
      const oldSessionsTableData = [
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
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 5,
        newVersion: 6,
        createOld: v5.DatabaseAtV5.new,
        createNew: v6.DatabaseAtV6.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
          batch.insertAll(oldDb.sessionsTable, oldSessionsTableData);
        },
        validateItems: (newDb) async {
          expect(
            await newDb.select(newDb.sessionsTable).get(),
            unorderedEquals(const [
              v6.SessionsTableData(
                sessionId: 'session-1',
                projectId: 'project-1',
                worktreePath: '/tmp/worktrees/session-1',
                branchName: 'feat/one',
                isDedicated: 1,
                archivedAt: null,
                baseBranch: 'main',
                baseCommit: 'abc123',
                lastAgent: null,
                lastAgentModel: null,
                createdAt: 1700000000000,
              ),
              v6.SessionsTableData(
                sessionId: 'session-2',
                projectId: 'project-1',
                worktreePath: null,
                branchName: null,
                isDedicated: 0,
                archivedAt: 1700000001000,
                baseBranch: null,
                baseCommit: null,
                lastAgent: null,
                lastAgentModel: null,
                createdAt: 1700000002000,
              ),
            ]),
          );
        },
      );
    },
  );

  test('migration v6 → v7 structural validation', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 7);
    await db.close();
  });

  test(
    'migration v6 → v7 preserves sessions and defaults unseen fields to null',
    () async {
      const oldProjectsTableData = [
        v6.ProjectsTableData(
          projectId: 'project-1',
          hidden: 0,
          baseBranch: 'main',
          worktreeCounter: 2,
        ),
      ];
      const oldSessionsTableData = [
        v6.SessionsTableData(
          sessionId: 'session-1',
          projectId: 'project-1',
          worktreePath: '/tmp/worktrees/session-1',
          branchName: 'feat/one',
          isDedicated: 1,
          archivedAt: null,
          baseBranch: 'main',
          baseCommit: 'abc123',
          lastAgent: 'build',
          lastAgentModel: 'anthropic|claude',
          createdAt: 1700000000000,
        ),
        v6.SessionsTableData(
          sessionId: 'session-2',
          projectId: 'project-1',
          worktreePath: null,
          branchName: null,
          isDedicated: 0,
          archivedAt: 1700000001000,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 1700000002000,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 6,
        newVersion: 7,
        createOld: v6.DatabaseAtV6.new,
        createNew: v7.DatabaseAtV7.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
          batch.insertAll(oldDb.sessionsTable, oldSessionsTableData);
        },
        validateItems: (newDb) async {
          expect(
            await newDb.select(newDb.sessionsTable).get(),
            unorderedEquals(const [
              v7.SessionsTableData(
                sessionId: 'session-1',
                projectId: 'project-1',
                worktreePath: '/tmp/worktrees/session-1',
                branchName: 'feat/one',
                isDedicated: 1,
                archivedAt: null,
                baseBranch: 'main',
                baseCommit: 'abc123',
                lastAgent: 'build',
                lastAgentModel: 'anthropic|claude',
                createdAt: 1700000000000,
                lastActivityAt: null,
                lastSeenAt: null,
                lastUserMessageAt: null,
              ),
              v7.SessionsTableData(
                sessionId: 'session-2',
                projectId: 'project-1',
                worktreePath: null,
                branchName: null,
                isDedicated: 0,
                archivedAt: 1700000001000,
                baseBranch: null,
                baseCommit: null,
                lastAgent: null,
                lastAgentModel: null,
                createdAt: 1700000002000,
                lastActivityAt: null,
                lastSeenAt: null,
                lastUserMessageAt: null,
              ),
            ]),
          );
        },
      );
    },
  );

  test(
    'deleting a project on the current schema cascades to sessions and PRs',
    () async {
      final db = await _migrateFromV4(verifier: verifier);
      addTearDown(db.close);

      await db
          .into(db.projectsTable)
          .insert(
            ProjectsTableCompanion.insert(projectId: 'p1', path: 'p1'),
          );
      await db
          .into(db.sessionTable)
          .insert(
            SessionTableCompanion.insert(
              sessionId: 's1',
              projectId: 'p1',
              isDedicated: false,
              createdAt: 1000,
              pluginId: 'opencode',
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
              pluginId: 'opencode',
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

  test('migration v7 → v8 structural validation', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 8);
    await db.close();
  });

  test(
    'migration v7 → v8 backfills path from projectId, openedAt with now, and pluginId with opencode',
    () async {
      const oldProjectsTableData = [
        v7.ProjectsTableData(
          projectId: 'project-1',
          hidden: 0,
          baseBranch: 'main',
          worktreeCounter: 2,
        ),
      ];
      const oldSessionsTableData = [
        v7.SessionsTableData(
          sessionId: 'session-1',
          projectId: 'project-1',
          worktreePath: '/tmp/worktrees/session-1',
          branchName: 'feat/one',
          isDedicated: 1,
          archivedAt: null,
          baseBranch: 'main',
          baseCommit: 'abc123',
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 1700000000000,
          lastActivityAt: 1700000005000,
          lastSeenAt: 1700000006000,
          lastUserMessageAt: 1700000004000,
        ),
      ];
      final beforeMigrationMs = DateTime.now().millisecondsSinceEpoch;

      await verifier.testWithDataIntegrity(
        oldVersion: 7,
        newVersion: 8,
        createOld: v7.DatabaseAtV7.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.projectsTable, oldProjectsTableData);
          batch.insertAll(oldDb.sessionsTable, oldSessionsTableData);
        },
        validateItems: (newDb) async {
          // Prior columns are preserved; path backfills from the project id
          // (ids have always been directory paths), displayName defaults to
          // null, and openedAt backfills with the migration wall-clock time.
          final projects = await newDb.select(newDb.projectsTable).get();
          expect(projects, hasLength(1));
          final project = projects.single;
          expect(project.projectId, 'project-1');
          expect(project.path, 'project-1');
          expect(project.hidden, 0);
          expect(project.baseBranch, 'main');
          expect(project.worktreeCounter, 2);
          expect(project.displayName, isNull);
          expect(project.openedAt, greaterThanOrEqualTo(beforeMigrationMs));
          expect(
            project.openedAt,
            lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch),
          );
          // The pre-existing session is backfilled to the opencode plugin; the
          // unseen-tracking timestamps survive the table rebuild.
          expect(
            await newDb.select(newDb.sessionsTable).get(),
            const [
              v8.SessionsTableData(
                sessionId: 'session-1',
                projectId: 'project-1',
                worktreePath: '/tmp/worktrees/session-1',
                branchName: 'feat/one',
                isDedicated: 1,
                archivedAt: null,
                baseBranch: 'main',
                baseCommit: 'abc123',
                lastAgent: null,
                lastAgentModel: null,
                createdAt: 1700000000000,
                lastActivityAt: 1700000005000,
                lastSeenAt: 1700000006000,
                lastUserMessageAt: 1700000004000,
                pluginId: 'opencode',
              ),
            ],
          );
          // The session→project FK survives the table rebuilds.
          expect(
            await newDb.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        },
      );
    },
  );
}

/// Migrates a v4 database to the current schema, so tests can insert rows with
/// the current companions and prove the FK graph introduced in v5 survives the
/// later table rebuilds.
Future<AppDatabase> _migrateFromV4({required SchemaVerifier verifier}) async {
  final connection = await verifier.startAt(4);
  final db = AppDatabase(connection);
  await verifier.migrateAndValidate(
    db,
    8,
    options: const ValidationOptions(validateDropped: true),
  );
  return db;
}

final Matcher _isForeignKeyViolation = isA<SqliteException>().having(
  (exception) => exception.toString().toUpperCase(),
  'message',
  contains('FOREIGN KEY'),
);
