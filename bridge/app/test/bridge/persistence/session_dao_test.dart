import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionDao.insertSession UPSERT", () {
    late AppDatabase db;
    late SessionDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.sessionDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("adopts the create flow's canonical project id over a placeholder", () async {
      // A placeholder row keyed to the plugin-supplied (pre-canonicalization)
      // worktree path, e.g. inserted by the unseen service from a live
      // session.created before the create handler persists the row.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo/.worktrees/s1"]);
      await dao.insertSessionsIfMissing(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "s1",
            backendSessionId: "s1",
            projectId: "/repo/.worktrees/s1",
            directory: "/repo/.worktrees/s1",
            createdAt: 100,
            archivedAt: null,
          ),
        ],
      );

      // The create flow inserts the same session under the original project id
      // (its project row exists first, satisfying the FK).
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "s1",
            currentBranchName: "stale-branch",
            currentGithubRepositoryIdentity: "stale/repository",
          ),
        ],
      );
      await dao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 200,
        worktreePath: "/repo/.worktrees/s1",
        branchName: "s1",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final dto = await dao.getSession(sessionId: "s1");
      // The session is re-keyed to the canonical project, and created_at (which
      // a placeholder may have set) is preserved.
      expect(dto?.projectId, equals("/repo"));
      expect(dto?.createdAt, equals(100));
      expect(dto?.currentBranchName, isNull);
      expect(dto?.currentGithubRepositoryIdentity, isNull);
    });

    test("preserves PR scope when retrying the same project and branch binding", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await dao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 100,
        worktreePath: "/repo/.worktrees/s1",
        branchName: "feature/one",
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: null,
        lastAgentModel: null,
      );
      await dao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "s1",
            currentBranchName: "feature/one",
            currentGithubRepositoryIdentity: "org/repo",
          ),
        ],
      );

      await dao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: true,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 200,
        worktreePath: "/repo/.worktrees/s1",
        branchName: "feature/one",
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: null,
        lastAgentModel: null,
      );

      final dto = await dao.getSession(sessionId: "s1");
      expect(dto?.currentBranchName, "feature/one");
      expect(dto?.currentGithubRepositoryIdentity, "org/repo");
    });

    test("looks up a divergent stable id by its plugin/backend binding", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await dao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "stable-root-id",
        backendSessionId: "backend-root-id",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 100,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final dto = await dao.getSessionByBinding(
        pluginId: "opencode",
        backendSessionId: "backend-root-id",
      );

      expect(dto?.sessionId, equals("stable-root-id"));
      expect(dto?.backendSessionId, equals("backend-root-id"));
      expect(
        await dao.getSessionByBinding(
          pluginId: "codex",
          backendSessionId: "backend-root-id",
        ),
        isNull,
      );
    });

    test("getSessionIdsByBackendIds projects requested bindings of one plugin only", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      Future<void> insert({required String pluginId, required String sessionId, required String backendSessionId}) =>
          dao.insertSession(
            pluginId: pluginId,
            preservePullRequestScope: false,
            sessionId: sessionId,
            backendSessionId: backendSessionId,
            projectId: "/repo",
            isDedicated: false,
            createdAt: 100,
            worktreePath: null,
            branchName: null,
            baseBranch: null,
            baseCommit: null,
            lastAgent: null,
            lastAgentModel: null,
          );
      // Two plugins may reuse the same backend id; only the requested plugin's
      // binding may answer.
      await insert(pluginId: "opencode", sessionId: "stable-a", backendSessionId: "backend-shared");
      await insert(pluginId: "codex", sessionId: "stable-b", backendSessionId: "backend-shared");
      await insert(pluginId: "opencode", sessionId: "stable-c", backendSessionId: "backend-other");

      expect(
        await dao.getSessionIdsByBackendIds(
          pluginId: "opencode",
          backendSessionIds: ["backend-shared", "backend-missing"],
        ),
        {"backend-shared": "stable-a"},
      );
      expect(
        await dao.getSessionIdsByBackendIds(pluginId: "codex", backendSessionIds: ["backend-shared"]),
        {"backend-shared": "stable-b"},
      );
      expect(await dao.getSessionIdsByBackendIds(pluginId: "opencode", backendSessionIds: const []), isEmpty);
    });

    test("archive clears prompt defaults while observed upsert preserves other bridge metadata", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await dao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "stable-root-id",
        backendSessionId: "backend-root-id",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 100,
        worktreePath: "/repo/.worktrees/root",
        branchName: "feature/root",
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: "build",
        lastAgentModel: const AgentModel(
          providerID: "provider",
          modelID: "model",
          variant: "high",
        ),
      );
      await dao.setArchived(
        sessionId: "stable-root-id",
        archivedAt: 150,
        updatedAt: 150,
        projectionUpdatedAt: 150,
      );
      await dao.setTitle(
        sessionId: "stable-root-id",
        title: "Bridge title",
        updatedAt: 200,
        projectionUpdatedAt: 200,
      );

      final rows = await dao.upsertObservedRootSessions(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "stable-root-id",
            backendSessionId: "backend-root-id",
            projectId: "/repo",
            directory: "/observed/repo",
            catalogTitle: "Backend title",
            createdAt: 90,
            updatedAt: 300,
            archivedAt: null,
            projectionUpdatedAt: 300,
          ),
        ],
      );

      final dto = rows["backend-root-id"];
      expect(dto?.title, equals("Bridge title"));
      expect(dto?.catalogTitle, equals("Backend title"));
      expect(dto?.worktreePath, equals("/repo/.worktrees/root"));
      expect(dto?.branchName, equals("feature/root"));
      expect(dto?.baseBranch, equals("main"));
      expect(dto?.baseCommit, equals("abc123"));
      expect(dto?.lastAgent, isNull);
      expect(dto?.lastAgentModel, isNull);
      expect(dto?.archivedAt, equals(150));
      expect(dto?.directory, equals("/observed/repo"));
      expect(dto?.createdAt, equals(100));
      expect(dto?.updatedAt, equals(300));
    });

    test("observed root upsert rejects stale projection regressions", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await dao.upsertObservedRootSessions(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "stable-root-id",
            backendSessionId: "backend-root-id",
            projectId: "/repo",
            directory: "/repo/current",
            catalogTitle: "Current title",
            createdAt: 100,
            updatedAt: 300,
            archivedAt: null,
            projectionUpdatedAt: 300,
          ),
        ],
      );

      final rows = await dao.upsertObservedRootSessions(
        pluginId: "opencode",
        sessions: [
          (
            sessionId: "stable-root-id",
            backendSessionId: "backend-root-id",
            projectId: "/repo",
            directory: "/repo/stale",
            catalogTitle: "Stale title",
            createdAt: 50,
            updatedAt: 200,
            archivedAt: 123,
            projectionUpdatedAt: 200,
          ),
        ],
      );

      final dto = rows["backend-root-id"];
      expect(dto?.directory, equals("/repo/current"));
      expect(dto?.catalogTitle, equals("Current title"));
      expect(dto?.createdAt, equals(100));
      expect(dto?.updatedAt, equals(300));
      expect(dto?.projectionUpdatedAt, equals(300));
      expect(dto?.archivedAt, isNull);
    });
  });
}
