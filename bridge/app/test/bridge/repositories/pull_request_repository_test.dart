import "package:sesori_bridge/src/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PullRequestRepository", () {
    const githubLogin = "octocat";
    const githubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo";
    final verifiedGithubLogin = VerifiedGithubLogin.tryParse(rawLogin: githubLogin)!;
    final previousVerifiedGithubLogin = VerifiedGithubLogin.tryParse(
      rawLogin: "previous-account",
    )!;
    late AppDatabase db;
    late PullRequestRepository repository;

    setUp(() {
      db = createTestDatabase();
      repository = PullRequestRepository(
        database: db,
        pullRequestDao: db.pullRequestDao,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
      );
    });

    tearDown(() => db.close());

    GhPullRequest ghPr({required int number, required String branchName}) {
      return GhPullRequest(
        number: number,
        url: "https://github.com/$githubRepositoryIdentity/pull/$number",
        title: "Test PR $number",
        state: PrState.open,
        headRefName: branchName,
        mergeable: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.reviewRequired,
        statusCheckRollup: PrCheckStatus.success,
      );
    }

    Future<void> insertRootSession({required String branchName}) async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["X"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "root",
        backendSessionId: "root",
        projectId: "X",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp/root",
        branchName: branchName,
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: null,
        lastAgentModel: null,
      );
    }

    test("upsertFromGhPr ensures the project exists and persists PR scope", () async {
      await expectLater(
        () => repository.upsertFromGhPr(
          projectId: "X",
          githubRepositoryIdentity: githubRepositoryIdentity,
          verifiedGithubLogin: verifiedGithubLogin,
          pr: ghPr(number: 42, branchName: "feature-branch"),
          createdAt: 1,
          lastCheckedAt: 2,
        ),
        returnsNormally,
      );

      final projectRows = await db.select(db.projectsTable).get();
      expect(
        projectRows.map((row) => row.projectId),
        contains("X"),
        reason: "upsertFromGhPr must insert the project row if missing",
      );

      final prRows = await db.pullRequestDao.getActivePrsByProjectId(
        projectId: "X",
        githubRepositoryIdentity: githubRepositoryIdentity,
        githubLogin: githubLogin,
      );
      expect(prRows, hasLength(1));
      expect(prRows.single.prNumber, 42);
      expect(prRows.single.githubRepositoryIdentity, githubRepositoryIdentity);
      expect(prRows.single.githubLogin, githubLogin);
    });

    test("prepareScopedRefresh establishes account and root repository scope", () async {
      await insertRootSession(branchName: "feature/root");
      await db.sessionDao.insertObservedChild(
        sessionId: "child",
        backendSessionId: "child",
        projectId: "X",
        parentSessionId: "root",
        directory: "/tmp/root/child",
        catalogTitle: null,
        archivedAt: null,
        createdAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
        pluginId: "opencode",
      );
      await db.projectsDao.setPrCacheGithubLogin(
        projectId: "X",
        githubLogin: "previous-account",
      );
      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "root",
            currentBranchName: "stale-root",
            currentGithubRepositoryIdentity: "previous/repository",
          ),
          (
            sessionId: "child",
            currentBranchName: "stale-child",
            currentGithubRepositoryIdentity: "previous/repository",
          ),
        ],
      );
      await repository.upsertFromGhPr(
        projectId: "X",
        githubRepositoryIdentity: "previous/repository",
        verifiedGithubLogin: previousVerifiedGithubLogin,
        pr: ghPr(number: 1, branchName: "stale-root"),
        createdAt: 1,
        lastCheckedAt: 1,
      );
      await repository.upsertFromGhPr(
        projectId: "X",
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        pr: ghPr(number: 2, branchName: "feature/root"),
        createdAt: 2,
        lastCheckedAt: 2,
      );
      final storedSessions = (await db.sessionDao.getSessionsByProject(
        projectId: "X",
      )).map((row) => row.toStoredSession()).toList(growable: false);

      await repository.prepareScopedRefresh(
        projectId: "X",
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        sessions: storedSessions,
      );

      final project = await db.projectsDao.getProject(projectId: "X");
      final root = await db.sessionDao.getSession(sessionId: "root");
      final child = await db.sessionDao.getSession(sessionId: "child");
      final prs = await db.pullRequestDao.getPrsByProjectId(projectId: "X");
      expect(project?.prCacheGithubLogin, githubLogin);
      expect(root?.currentBranchName, "feature/root");
      expect(root?.currentGithubRepositoryIdentity, githubRepositoryIdentity);
      expect(child?.currentBranchName, isNull);
      expect(child?.currentGithubRepositoryIdentity, isNull);
      expect(prs.map((pr) => pr.prNumber), [2]);
    });

    test("prepareScopedRefresh rolls back account and session scope on failure", () async {
      await insertRootSession(branchName: "feature/root");
      await db.projectsDao.setPrCacheGithubLogin(
        projectId: "X",
        githubLogin: "previous-account",
      );
      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "root",
            currentBranchName: "previous-branch",
            currentGithubRepositoryIdentity: "previous/repository",
          ),
        ],
      );
      final storedSession = (await db.sessionDao.getSession(
        sessionId: "root",
      ))!.toStoredSession();
      final failingRepository = PullRequestRepository(
        database: db,
        pullRequestDao: _FailingScopeCleanupPullRequestDao(db),
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
      );

      await expectLater(
        failingRepository.prepareScopedRefresh(
          projectId: "X",
          githubRepositoryIdentity: githubRepositoryIdentity,
          verifiedGithubLogin: verifiedGithubLogin,
          sessions: [storedSession],
        ),
        throwsStateError,
      );

      final project = await db.projectsDao.getProject(projectId: "X");
      final session = await db.sessionDao.getSession(sessionId: "root");
      expect(project?.prCacheGithubLogin, "previous-account");
      expect(session?.currentBranchName, "previous-branch");
      expect(session?.currentGithubRepositoryIdentity, "previous/repository");
    });

    test("clearScopedRefresh clears scope and cached rows atomically", () async {
      await insertRootSession(branchName: "feature/root");
      final storedSession = (await db.sessionDao.getSession(
        sessionId: "root",
      ))!.toStoredSession();
      await repository.prepareScopedRefresh(
        projectId: "X",
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        sessions: [storedSession],
      );
      await repository.upsertFromGhPr(
        projectId: "X",
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        pr: ghPr(number: 7, branchName: "feature/root"),
        createdAt: 1,
        lastCheckedAt: 1,
      );

      await repository.clearScopedRefresh(
        projectId: "X",
        sessions: [storedSession],
      );

      final project = await db.projectsDao.getProject(projectId: "X");
      final session = await db.sessionDao.getSession(sessionId: "root");
      expect(project?.prCacheGithubLogin, isNull);
      expect(session?.currentBranchName, isNull);
      expect(session?.currentGithubRepositoryIdentity, isNull);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: "X"), isEmpty);
    });
  });
}

class _FailingScopeCleanupPullRequestDao extends PullRequestDao {
  _FailingScopeCleanupPullRequestDao(super.database);

  @override
  Future<void> deletePrsOutsideRepositoryScope({
    required String projectId,
    required String githubRepositoryIdentity,
  }) {
    throw StateError("scope cleanup failed");
  }
}
