import "package:drift/drift.dart" show Value;
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("SessionDao", () {
    late AppDatabase db;
    late SessionDao dao;
    late ProjectsDao projectsDao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.sessionDao;
      projectsDao = db.projectsDao;
      // Seed projects required by tests — v5 FK constraint on session_table.projectId
      // → projects_table.projectId means every session insert needs a matching project row.
      for (final id in ["proj-1", "proj-2", "proj-3", "proj-4", "proj-x", "proj-y"]) {
        await projectsDao.insertProjectsIfMissing(projectIds: [id]);
      }
    });

    tearDown(() async {
      await db.close();
    });

    test("insert dedicated session then retrieve by sessionId returns matching row", () async {
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-1",
        backendSessionId: "ses-1",
        projectId: "proj-1",
        isDedicated: true,
        createdAt: createdAt,
        worktreePath: "/tmp/worktrees/ses-1",
        branchName: "feat/my-feature",
        baseBranch: "main",
        baseCommit: "abc123",

        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await dao.getSession(sessionId: "ses-1");

      expect(result, isNotNull);
      expect(result!.sessionId, equals("ses-1"));
      expect(result.projectId, equals("proj-1"));
      expect(result.isDedicated, isTrue);
      expect(result.createdAt, equals(createdAt));
      expect(result.worktreePath, equals("/tmp/worktrees/ses-1"));
      expect(result.branchName, equals("feat/my-feature"));
      expect(result.baseBranch, equals("main"));
      expect(result.baseCommit, equals("abc123"));
      expect(result.archivedAt, isNull);
    });

    test("insert simple session supports null worktree fields", () async {
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-simple",
        backendSessionId: "ses-simple",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: createdAt,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await dao.getSession(sessionId: "ses-simple");

      expect(result, isNotNull);
      expect(result!.isDedicated, isFalse);
      expect(result.worktreePath, isNull);
      expect(result.branchName, isNull);
      expect(result.baseBranch, isNull);
      expect(result.baseCommit, isNull);
      expect(result.createdAt, equals(createdAt));
    });

    test("generated companion insert persists last default selection fields", () async {
      await db
          .into(db.sessionTable)
          .insert(
            SessionTableCompanion.insert(
              pluginId: "opencode",
              sessionId: "ses-defaults",
              backendSessionId: "ses-defaults",
              projectId: "proj-1",
              directory: "proj-1",
              isDedicated: false,
              createdAt: 1234,
              updatedAt: 1234,
              projectionUpdatedAt: 1234,
              lastAgent: const Value("opencode"),
              lastAgentModel: const Value(
                AgentModel(
                  providerID: "anthropic",
                  modelID: "claude-sonnet-4",
                  variant: "standard",
                ),
              ),
            ),
          );

      final result = await dao.getSession(sessionId: "ses-defaults");

      expect(result, isNotNull);
      expect(result!.lastAgent, equals("opencode"));
      expect(result.lastAgentModel?.providerID, equals("anthropic"));
      expect(result.lastAgentModel?.modelID, equals("claude-sonnet-4"));
      expect(result.lastAgentModel?.variant, equals("standard"));
    });

    test("insertSession persists optional prompt defaults", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-insert-defaults",
        backendSessionId: "ses-insert-defaults",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: 1234,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: "opencode",
        lastAgentModel: const AgentModel(
          providerID: "anthropic",
          modelID: "claude-sonnet-4",
          variant: "standard",
        ),
      );

      final result = await dao.getSession(sessionId: "ses-insert-defaults");

      expect(result, isNotNull);
      expect(result!.lastAgent, equals("opencode"));
      expect(result.lastAgentModel?.providerID, equals("anthropic"));
      expect(result.lastAgentModel?.modelID, equals("claude-sonnet-4"));
      expect(result.lastAgentModel?.variant, equals("standard"));
    });

    test("updatePromptDefaults overwrites all prompt default fields", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-update-defaults",
        backendSessionId: "ses-update-defaults",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: 1234,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: "old-agent",
        lastAgentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );

      await dao.updatePromptDefaults(
        sessionId: "ses-update-defaults",
        agent: null,
        agentModel: const AgentModel(
          providerID: "new-provider",
          modelID: "new-model",
          variant: null,
        ),
      );

      final result = await dao.getSession(sessionId: "ses-update-defaults");

      expect(result, isNotNull);
      expect(result!.lastAgent, isNull);
      expect(result.lastAgentModel?.providerID, equals("new-provider"));
      expect(result.lastAgentModel?.modelID, equals("new-model"));
      expect(result.lastAgentModel?.variant, isNull);
    });

    test("get non-existent sessionId returns null", () async {
      final result = await dao.getSession(sessionId: "does-not-exist");

      expect(result, isNull);
    });

    test("delete session then get returns null", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-2",
        backendSessionId: "ses-2",
        projectId: "proj-2",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-2",
        branchName: "main",
        baseBranch: "main",
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );

      await dao.deleteSession(sessionId: "ses-2");

      final result = await dao.getSession(sessionId: "ses-2");
      expect(result, isNull);
    });

    test("deleteSession is no-op for unknown sessionId", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-3",
        backendSessionId: "ses-3",
        projectId: "proj-3",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-3",
        branchName: "develop",
        baseBranch: "develop",
        baseCommit: "commit-1",

        lastAgent: null,
        lastAgentModel: null,
      );

      await dao.deleteSession(sessionId: "does-not-exist");

      final result = await dao.getSession(sessionId: "ses-3");
      expect(result, isNotNull);
    });

    test("tombstones scope the same session id independently by plugin", () async {
      await dao.insertSessionTombstone(
        backendSessionId: "shared-id",
        pluginId: "acp",
        deletedAt: 1,
      );
      await dao.insertSessionTombstone(
        backendSessionId: "shared-id",
        pluginId: "codex",
        deletedAt: 2,
      );

      expect(await dao.isSessionTombstoned(backendSessionId: "shared-id", pluginId: "acp"), isTrue);
      expect(await dao.isSessionTombstoned(backendSessionId: "shared-id", pluginId: "codex"), isTrue);
      expect(await dao.isSessionTombstoned(backendSessionId: "shared-id", pluginId: "other"), isFalse);
    });

    test("tombstone reads are scoped to the current owner", () async {
      await db
          .into(db.deletedSessionsTable)
          .insert(
            DeletedSessionsTableCompanion.insert(
              ownerIdentity: const Value("other-owner"),
              backendSessionId: "shared-id",
              pluginId: "codex",
              deletedAt: 1,
            ),
          );

      expect(await dao.isSessionTombstoned(backendSessionId: "shared-id", pluginId: "codex"), isFalse);
      expect(await dao.getTombstonedSessionIds(pluginId: "codex"), isEmpty);
    });

    test("setArchived and clearArchived update archivedAt", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-4",
        backendSessionId: "ses-4",
        projectId: "proj-4",
        isDedicated: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );

      await dao.setArchived(
        sessionId: "ses-4",
        archivedAt: 1234567890,
        updatedAt: 1234567890,
        projectionUpdatedAt: 1234567890,
      );
      var result = await dao.getSession(sessionId: "ses-4");
      expect(result!.archivedAt, equals(1234567890));

      await dao.clearArchived(
        sessionId: "ses-4",
        updatedAt: 1234567891,
        projectionUpdatedAt: 1234567891,
      );
      result = await dao.getSession(sessionId: "ses-4");
      expect(result!.archivedAt, isNull);
    });

    test("getSessionsByProject and getSessionsByIds return expected sessions", () async {
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-a",
        backendSessionId: "ses-a",
        projectId: "proj-x",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp/worktrees/ses-a",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "sha-a",

        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-b",
        backendSessionId: "ses-b",
        projectId: "proj-x",
        isDedicated: false,
        createdAt: 2,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "ses-c",
        backendSessionId: "ses-c",
        projectId: "proj-y",
        isDedicated: true,
        createdAt: 3,
        worktreePath: "/tmp/worktrees/ses-c",
        branchName: "session-003",
        baseBranch: "develop",
        baseCommit: "sha-c",

        lastAgent: null,
        lastAgentModel: null,
      );

      final projectSessions = await dao.getSessionsByProject(projectId: "proj-x");
      expect(projectSessions.map((session) => session.sessionId), containsAll(<String>["ses-a", "ses-b"]));
      expect(projectSessions.map((session) => session.sessionId), isNot(contains("ses-c")));

      final byIds = await dao.getSessionsByIds(sessionIds: <String>["ses-a", "ses-c", "missing"]);
      expect(byIds.keys, containsAll(<String>["ses-a", "ses-c"]));
      expect(byIds.containsKey("missing"), isFalse);
      expect(byIds["ses-a"]!.projectId, equals("proj-x"));
      expect(byIds["ses-c"]!.projectId, equals("proj-y"));
    });

    group("getOtherActiveSessionsSharing", () {
      test("returns empty when both params are null", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-1",
          backendSessionId: "ses-1",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt",
          branchName: "branch-1",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-1",
          projectId: "proj-1",
          worktreePath: null,
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("finds other session sharing worktreePath", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
          branchName: "branch-b",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, hasLength(1));
        expect(result.first.sessionId, "ses-b");
      });

      test("finds other session sharing branchName", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "shared-branch",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-b",
          branchName: "shared-branch",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: null,
          branchName: "shared-branch",
        );

        expect(result, hasLength(1));
        expect(result.first.sessionId, "ses-b");
      });

      test("excludes the current session from results", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("excludes archived sessions", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
          branchName: "branch-b",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.setArchived(
          sessionId: "ses-b",
          archivedAt: 99999,
          updatedAt: 99999,
          projectionUpdatedAt: 99999,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("uses OR logic when both worktreePath and branchName provided", () async {
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-a",
          branchName: "branch-other",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-c",
          backendSessionId: "ses-c",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 3,
          worktreePath: "/wt-other",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/wt-a",
          branchName: "branch-a",
        );

        expect(result, hasLength(2));
        expect(result.map((s) => s.sessionId), containsAll(["ses-b", "ses-c"]));
      });

      test("excludes sessions from other projects", () async {
        // Two sessions in different projects accidentally share the same branch
        // name. Cleanup of one must not be blocked by the other.
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "session-001",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-2",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-a",
          branchName: "session-001",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/wt-a",
          branchName: "session-001",
        );

        expect(result, isEmpty);
      });
    });

    test(
      "insertSessionsIfMissing inserts placeholder session with isDedicated=false and null nullable fields",
      () async {
        // proj-1 is seeded in setUp — FK constraint satisfied.
        await dao.insertSessionsIfMissing(
          pluginId: "opencode",
          sessions: [
            (
              sessionId: "sess-1",
              backendSessionId: "sess-1",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 1000,
              archivedAt: null,
            ),
          ],
        );

        final result = await dao.getSession(sessionId: "sess-1");

        expect(result, isNotNull);
        expect(result!.sessionId, equals("sess-1"));
        expect(result.projectId, equals("proj-1"));
        expect(result.isDedicated, isFalse);
        expect(result.createdAt, equals(1000));
        expect(result.worktreePath, isNull);
        expect(result.branchName, isNull);
        expect(result.archivedAt, isNull);
        expect(result.baseBranch, isNull);
        expect(result.baseCommit, isNull);
      },
    );

    test("insertSessionsIfMissing persists archivedAt when provided", () async {
      await dao.insertSessionsIfMissing(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "sess-archived",
            backendSessionId: "sess-archived",
            projectId: "proj-1",
            directory: "proj-1",
            createdAt: 1000,
            archivedAt: 9999,
          ),
        ],
      );

      final result = await dao.getSession(sessionId: "sess-archived");
      expect(result, isNotNull);
      expect(result!.archivedAt, equals(9999));
    });

    test("insertSessionsIfMissing is no-op when session exists, preserving worktreePath and branchName", () async {
      // Pre-insert a full session with worktree state.
      await dao.insertSession(
        pluginId: "opencode",
        sessionId: "sess-existing",
        backendSessionId: "sess-existing",
        projectId: "proj-1",
        isDedicated: true,
        createdAt: 500,
        worktreePath: "/tmp/wt",
        branchName: "feature-x",
        baseBranch: "main",
        baseCommit: "abc123",

        lastAgent: null,
        lastAgentModel: null,
      );

      // insertSessionsIfMissing must be a no-op — must NOT clobber existing fields.
      await dao.insertSessionsIfMissing(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "sess-existing",
            backendSessionId: "sess-existing",
            projectId: "proj-1",
            directory: "proj-1",
            createdAt: 999,
            archivedAt: null,
          ),
        ],
      );

      final result = await dao.getSession(sessionId: "sess-existing");

      expect(result, isNotNull);
      expect(result!.worktreePath, equals("/tmp/wt"));
      expect(result.branchName, equals("feature-x"));
      expect(result.isDedicated, isTrue);
      expect(result.createdAt, equals(500));
    });

    test(
      "insertSessionsIfMissing rejects an unknown project",
      () async {
        // Fresh in-memory AppDatabase at v5 with FK enforced.
        // projects_table is empty — no row for "nonexistent".
        // The v5 FK constraint on session_table.projectId → projects_table.projectId
        // must reject this insert at the SQLite level.
        expect(
          () async => dao.insertSessionsIfMissing(
            pluginId: "opencode",
            sessions: [
              (
                sessionId: "s1",
                backendSessionId: "s1",
                projectId: "nonexistent",
                directory: "nonexistent",
                createdAt: 0,
                archivedAt: null,
              ),
            ],
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    group("insertSessionsIfMissing", () {
      test("insertSessionsIfMissing inserts all sessions in one batch", () async {
        await dao.insertSessionsIfMissing(
          pluginId: "opencode",
          sessions: [
            (
              sessionId: "bulk-1",
              backendSessionId: "bulk-1",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 100,
              archivedAt: null,
            ),
            (
              sessionId: "bulk-2",
              backendSessionId: "bulk-2",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 200,
              archivedAt: 9999,
            ),
            (
              sessionId: "bulk-3",
              backendSessionId: "bulk-3",
              projectId: "proj-2",
              directory: "proj-2",
              createdAt: 300,
              archivedAt: null,
            ),
          ],
        );

        final s1 = await dao.getSession(sessionId: "bulk-1");
        expect(s1, isNotNull);
        expect(s1!.isDedicated, isFalse);
        expect(s1.createdAt, equals(100));
        expect(s1.archivedAt, isNull);

        final s2 = await dao.getSession(sessionId: "bulk-2");
        expect(s2, isNotNull);
        expect(s2!.archivedAt, equals(9999));

        final s3 = await dao.getSession(sessionId: "bulk-3");
        expect(s3, isNotNull);
        expect(s3!.projectId, equals("proj-2"));
      });

      test("insertSessionsIfMissing is no-op for empty list", () async {
        await dao.insertSessionsIfMissing(pluginId: "opencode", sessions: []);

        final rows = await db.select(db.sessionTable).get();
        expect(rows, isEmpty);
      });
    });

    group("deleteSessionsForProjectNotIn", () {
      test("only reconciles rows of the given plugin", () async {
        // The authoritative session list comes from the active plugin, so
        // another plugin's rows for the same project are legitimately absent
        // from it and must survive the reconciliation.
        await dao.insertSessionsIfMissing(
          pluginId: "codex",
          sessions: [
            (
              sessionId: "c-gone",
              backendSessionId: "c-gone",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 100,
              archivedAt: null,
            ),
            (
              sessionId: "c-kept",
              backendSessionId: "c-kept",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 100,
              archivedAt: null,
            ),
          ],
        );
        await dao.insertSessionsIfMissing(
          pluginId: "opencode",
          sessions: [
            (
              sessionId: "o-kept",
              backendSessionId: "o-kept",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 100,
              archivedAt: null,
            ),
          ],
        );

        final deleted = await dao.deleteSessionsForProjectNotIn(
          projectId: "proj-1",
          keepSessionIds: ["c-kept"],
          createdBefore: 500,
          pluginId: "codex",
        );

        expect(deleted, equals(["c-gone"]));
        expect(await dao.getSession(sessionId: "c-kept"), isNotNull);
        expect(await dao.getSession(sessionId: "o-kept"), isNotNull);
      });
    });

    group("getSessionProjectPaths", () {
      test("joins each session to its project's stored path, filtered by plugin id", () async {
        await dao.insertSessionsIfMissing(
          pluginId: "codex",
          sessions: [
            (
              sessionId: "c1",
              backendSessionId: "c1",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 100,
              archivedAt: null,
            ),
            (
              sessionId: "c2",
              backendSessionId: "c2",
              projectId: "proj-2",
              directory: "proj-2",
              createdAt: 200,
              archivedAt: null,
            ),
          ],
        );
        await dao.insertSessionsIfMissing(
          pluginId: "opencode",
          sessions: [
            (
              sessionId: "o1",
              backendSessionId: "o1",
              projectId: "proj-1",
              directory: "proj-1",
              createdAt: 300,
              archivedAt: null,
            ),
          ],
        );

        final rows = await dao.getSessionProjectPaths(pluginId: "codex");

        expect(
          {for (final row in rows) row.sessionId: row.projectPath},
          equals({"c1": "proj-1", "c2": "proj-2"}),
        );
      });

      test("returns empty when the plugin has no recorded sessions", () async {
        expect(await dao.getSessionProjectPaths(pluginId: "codex"), isEmpty);
      });
    });

    test(
      "insertSession rejects an unknown project",
      () async {
        // Same FK enforcement proof but via the existing insertSession path.
        // Proves the v5 FK constraint catches BOTH session insert paths.
        expect(
          () async => dao.insertSession(
            pluginId: "opencode",
            sessionId: "s2",
            backendSessionId: "s2",
            projectId: "nonexistent",
            isDedicated: false,
            createdAt: 0,
            worktreePath: null,
            branchName: null,
            baseBranch: null,
            baseCommit: null,

            lastAgent: null,
            lastAgentModel: null,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
