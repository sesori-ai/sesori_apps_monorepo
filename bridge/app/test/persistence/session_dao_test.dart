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
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-1",
        backendSessionId: "ses-1",
        projectId: "proj-1",
        isDedicated: true,
        createdAt: createdAt,
        worktreePath: "/tmp/worktrees/ses-1",
        baseBranch: "main",
        baseCommit: "abc123",

        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await dao.getSession(sessionId: "ses-1") ?? fail("session ses-1 is not stored");

      expect(result.sessionId, equals("ses-1"));
      expect(result.projectId, equals("proj-1"));
      expect(result.isDedicated, isTrue);
      expect(result.createdAt, equals(createdAt));
      expect(result.worktreePath, equals("/tmp/worktrees/ses-1"));
      expect(result.branchName, isNull);
      expect(result.baseBranch, equals("main"));
      expect(result.baseCommit, equals("abc123"));
      expect(result.archivedAt, isNull);
    });

    test("insert simple session supports null worktree fields", () async {
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-simple",
        backendSessionId: "ses-simple",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: createdAt,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await dao.getSession(sessionId: "ses-simple") ?? fail("session ses-simple is not stored");

      expect(result.isDedicated, isFalse);
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

      final result = await dao.getSession(sessionId: "ses-defaults") ?? fail("session ses-defaults is not stored");

      expect(result.lastAgent, equals("opencode"));
      expect(result.lastAgentModel?.providerID, equals("anthropic"));
      expect(result.lastAgentModel?.modelID, equals("claude-sonnet-4"));
      expect(result.lastAgentModel?.variant, equals("standard"));
    });

    test("insertSession persists optional prompt defaults", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-insert-defaults",
        backendSessionId: "ses-insert-defaults",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: 1234,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: "opencode",
        lastAgentModel: const AgentModel(
          providerID: "anthropic",
          modelID: "claude-sonnet-4",
          variant: "standard",
        ),
      );

      final result =
          await dao.getSession(sessionId: "ses-insert-defaults") ?? fail("session ses-insert-defaults is not stored");

      expect(result.lastAgent, equals("opencode"));
      expect(result.lastAgentModel?.providerID, equals("anthropic"));
      expect(result.lastAgentModel?.modelID, equals("claude-sonnet-4"));
      expect(result.lastAgentModel?.variant, equals("standard"));
    });

    test("updatePromptDefaults overwrites all prompt default fields", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-update-defaults",
        backendSessionId: "ses-update-defaults",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: 1234,
        worktreePath: null,
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

      final result =
          await dao.getSession(sessionId: "ses-update-defaults") ?? fail("session ses-update-defaults is not stored");

      expect(result.lastAgent, isNull);
      expect(result.lastAgentModel?.providerID, equals("new-provider"));
      expect(result.lastAgentModel?.modelID, equals("new-model"));
      expect(result.lastAgentModel?.variant, isNull);
    });

    test("setTitleIfNull ignores catalog title and does not replace a bridge title", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-generated-title",
        backendSessionId: "ses-generated-title",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.updateObservedSessionProjection(
        sessionId: "ses-generated-title",
        directory: "proj-1",
        catalogTitle: "Catalog title",
        updateCatalogTitle: true,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      expect(
        await dao.setTitleIfNull(
          sessionId: "ses-generated-title",
          title: "Generated title",
          updatedAt: 3,
          projectionUpdatedAt: 3,
        ),
        isTrue,
      );
      expect(
        await dao.setTitleIfNull(
          sessionId: "ses-generated-title",
          title: "Later generated title",
          updatedAt: 4,
          projectionUpdatedAt: 4,
        ),
        isFalse,
      );
      expect((await dao.getSession(sessionId: "ses-generated-title"))?.title, "Generated title");
    });

    test("setTitleIfNull reports a missing row", () async {
      expect(
        await dao.setTitleIfNull(
          sessionId: "does-not-exist",
          title: "Generated title",
          updatedAt: 1,
          projectionUpdatedAt: 1,
        ),
        isFalse,
      );
    });

    test("get non-existent sessionId returns null", () async {
      final result = await dao.getSession(sessionId: "does-not-exist");

      expect(result, isNull);
    });

    test("delete session then get returns null", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-2",
        backendSessionId: "ses-2",
        projectId: "proj-2",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-2",
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
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-3",
        backendSessionId: "ses-3",
        projectId: "proj-3",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-3",
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

    test("setArchived updates archivedAt", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-4",
        backendSessionId: "ses-4",
        projectId: "proj-4",
        isDedicated: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: null,
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
      final result = await dao.getSession(sessionId: "ses-4") ?? fail("session ses-4 is not stored");
      expect(result.archivedAt, equals(1234567890));
    });

    test("getSessionsByIds returns expected sessions", () async {
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-a",
        backendSessionId: "ses-a",
        projectId: "proj-x",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp/worktrees/ses-a",
        baseBranch: "main",
        baseCommit: "sha-a",

        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-b",
        backendSessionId: "ses-b",
        projectId: "proj-x",
        isDedicated: false,
        createdAt: 2,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.insertSession(
        fastMode: false,
        pluginId: "opencode",
        sessionId: "ses-c",
        backendSessionId: "ses-c",
        projectId: "proj-y",
        isDedicated: true,
        createdAt: 3,
        worktreePath: "/tmp/worktrees/ses-c",
        baseBranch: "develop",
        baseCommit: "sha-c",

        lastAgent: null,
        lastAgentModel: null,
      );

      final byIds = await dao.getSessionsByIds(sessionIds: <String>["ses-a", "ses-c", "missing"]);
      expect(byIds.keys, containsAll(<String>["ses-a", "ses-c"]));
      expect(byIds.containsKey("missing"), isFalse);
      expect(byIds.containsKey("ses-b"), isFalse);
      expect(byIds["ses-a"]?.projectId, equals("proj-x"));
      expect(byIds["ses-c"]?.projectId, equals("proj-y"));
    });

    group("getOtherActiveSessionsSharing", () {
      test("finds other session sharing worktreePath", () async {
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
        );

        expect(result, hasLength(1));
        expect(result.first.sessionId, "ses-b");
      });

      test("excludes the current session from results", () async {
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
        );

        expect(result, isEmpty);
      });

      test("excludes archived sessions", () async {
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
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
        );

        expect(result, isEmpty);
      });

      test("excludes sessions from other projects", () async {
        // Sessions in different projects never share a worktree, even when
        // their paths match. Cleanup of one must not be blocked by the other.
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-a",
          backendSessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );
        await dao.insertSession(
          fastMode: false,
          pluginId: "opencode",
          sessionId: "ses-b",
          backendSessionId: "ses-b",
          projectId: "proj-2",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-a",
          baseBranch: "main",
          baseCommit: null,

          lastAgent: null,
          lastAgentModel: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/wt-a",
        );

        expect(result, isEmpty);
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
        // The v5 FK constraint on session_table.projectId must reject a
        // session whose project row does not exist.
        expect(
          () async => await dao.insertSession(
            fastMode: false,
            pluginId: "opencode",
            sessionId: "s2",
            backendSessionId: "s2",
            projectId: "nonexistent",
            isDedicated: false,
            createdAt: 0,
            worktreePath: null,
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
