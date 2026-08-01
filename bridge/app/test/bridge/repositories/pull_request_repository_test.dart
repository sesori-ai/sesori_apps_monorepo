import "package:sesori_bridge/src/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
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

    PullRequestTargetSelected selectedPullRequest({required int number, required String branchName}) {
      return PullRequestTargetSelected(
        target: (
          githubRepositoryIdentity: githubRepositoryIdentity,
          branchName: branchName,
        ),
        number: number,
        url: "https://github.com/$githubRepositoryIdentity/pull/$number",
        title: "Test PR $number",
        createdAt: DateTime.fromMillisecondsSinceEpoch(number, isUtc: true),
        state: PrState.open,
        mergeableStatus: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.reviewRequired,
        checkStatus: PrCheckStatus.success,
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

    Future<void> insertPullRequest({
      required String repositoryIdentity,
      required String login,
      required int number,
      required String branchName,
    }) {
      return db.pullRequestDao.upsertPr(
        pullRequest: PullRequestDto(
          projectId: "X",
          githubRepositoryIdentity: repositoryIdentity,
          githubLogin: login,
          prNumber: number,
          branchName: branchName,
          url: "https://github.com/$repositoryIdentity/pull/$number",
          title: "Test PR $number",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.reviewRequired,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: number,
          createdAt: number,
        ),
      );
    }

    test("replaceScopedPullRequests persists selected PR scope", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["X"]);
      final changed = await repository.replaceScopedPullRequests(
        projectId: "X",
        verifiedGithubLogin: verifiedGithubLogin,
        targetSelections: [selectedPullRequest(number: 42, branchName: "feature-branch")],
        lastCheckedAt: 2,
      );

      final projectRows = await db.select(db.projectsTable).get();
      expect(projectRows.map((row) => row.projectId), contains("X"));

      final prRows = await db.pullRequestDao.getPrsByProjectId(projectId: "X");
      expect(prRows, hasLength(1));
      expect(prRows.single.prNumber, 42);
      expect(prRows.single.githubRepositoryIdentity, githubRepositoryIdentity);
      expect(prRows.single.githubLogin, githubLogin);
      expect(prRows.single.createdAt, 42);
      expect(changed, isTrue);
    });

    test("replaceScopedPullRequests does not fabricate a missing catalog project", () async {
      await expectLater(
        repository.replaceScopedPullRequests(
          projectId: "missing",
          verifiedGithubLogin: verifiedGithubLogin,
          targetSelections: [selectedPullRequest(number: 42, branchName: "feature-branch")],
          lastCheckedAt: 2,
        ),
        throwsA(anything),
      );

      expect(await db.projectsDao.getProject(projectId: "missing"), isNull);
    });

    test("replaceScopedPullRequests reports visible changes and clears complete no-match", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["X"]);
      await insertPullRequest(
        repositoryIdentity: githubRepositoryIdentity,
        login: verifiedGithubLogin.login,
        number: 42,
        branchName: "feature-branch",
      );

      final unchanged = await repository.replaceScopedPullRequests(
        projectId: "X",
        verifiedGithubLogin: verifiedGithubLogin,
        targetSelections: [selectedPullRequest(number: 42, branchName: "feature-branch")],
        lastCheckedAt: 100,
      );
      final cleared = await repository.replaceScopedPullRequests(
        projectId: "X",
        verifiedGithubLogin: verifiedGithubLogin,
        targetSelections: const [
          PullRequestTargetUnmatched(
            target: (
              githubRepositoryIdentity: githubRepositoryIdentity,
              branchName: "feature-branch",
            ),
          ),
        ],
        lastCheckedAt: 101,
      );

      expect(unchanged, isFalse);
      expect(cleared, isTrue);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: "X"), isEmpty);
    });

    test("replaceScopedPullRequests rejects duplicate target outcomes", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["X"]);
      final selected = selectedPullRequest(number: 42, branchName: "feature-branch");

      await expectLater(
        repository.replaceScopedPullRequests(
          projectId: "X",
          verifiedGithubLogin: verifiedGithubLogin,
          targetSelections: [
            selected,
            PullRequestTargetUnmatched(target: selected.target),
          ],
          lastCheckedAt: 2,
        ),
        throwsArgumentError,
      );
    });

    test("prepareScopedRefresh does not fabricate a missing catalog project", () async {
      final changed = await repository.prepareScopedRefresh(
        projectId: "missing",
        githubRepositoryIdentity: githubRepositoryIdentity,
        verifiedGithubLogin: verifiedGithubLogin,
        sessions: const [],
      );

      expect(changed, isFalse);
      expect(await db.projectsDao.getProject(projectId: "missing"), isNull);
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
      await insertPullRequest(
        repositoryIdentity: "previous/repository",
        login: previousVerifiedGithubLogin.login,
        number: 1,
        branchName: "stale-root",
      );
      await insertPullRequest(
        repositoryIdentity: githubRepositoryIdentity,
        login: verifiedGithubLogin.login,
        number: 2,
        branchName: "feature/root",
      );
      await insertPullRequest(
        repositoryIdentity: githubRepositoryIdentity,
        login: previousVerifiedGithubLogin.login,
        number: 3,
        branchName: "feature/root",
      );
      await insertPullRequest(
        repositoryIdentity: githubRepositoryIdentity,
        login: verifiedGithubLogin.login,
        number: 4,
        branchName: "departed-branch",
      );
      final storedSessions = (await db.sessionDao.getSessionsByProject(
        projectId: "X",
      )).map((row) => row.toStoredSession()).toList(growable: false);

      final changed = await repository.prepareScopedRefresh(
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
      expect(changed, isTrue);
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
      await insertPullRequest(
        repositoryIdentity: githubRepositoryIdentity,
        login: verifiedGithubLogin.login,
        number: 7,
        branchName: "feature/root",
      );

      final changed = await repository.clearScopedRefresh(
        projectId: "X",
        sessions: [storedSession],
      );

      final project = await db.projectsDao.getProject(projectId: "X");
      final session = await db.sessionDao.getSession(sessionId: "root");
      expect(project?.prCacheGithubLogin, isNull);
      expect(session?.currentBranchName, isNull);
      expect(session?.currentGithubRepositoryIdentity, isNull);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: "X"), isEmpty);
      expect(changed, isTrue);
    });
  });
}

class _FailingScopeCleanupPullRequestDao extends PullRequestDao {
  _FailingScopeCleanupPullRequestDao(super.database);

  @override
  Future<void> deletePrsOutsideScope({
    required String projectId,
    required String githubRepositoryIdentity,
    required String githubLogin,
    required Set<String> branchNames,
  }) {
    throw StateError("scope cleanup failed");
  }
}
