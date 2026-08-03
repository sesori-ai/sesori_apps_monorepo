import "package:sesori_bridge/src/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PullRequestRepository", () {
    const projectId = "X";
    const repositoryIdentity = "sesori-ai/sesori_apps_monorepo";
    final verifiedGithubLogin = VerifiedGithubLogin.tryParse(rawLogin: "octocat")!;
    late AppDatabase db;
    late PullRequestRepository repository;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.recordOpenedProject(
        projectId: projectId,
        path: "/project",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      repository = _repository(database: db, pullRequestDao: db.pullRequestDao);
    });

    tearDown(() => db.close());

    test("applies exact root-directory scopes and clears child scope", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _insertRoot(
        database: db,
        sessionId: "worktree-root",
        worktreePath: "/worktree",
        creationBranch: "created-worktree",
      );
      await db.sessionDao.insertObservedChild(
        sessionId: "child",
        backendSessionId: "child",
        projectId: projectId,
        parentSessionId: "project-root",
        directory: "/project/child",
        catalogTitle: null,
        archivedAt: null,
        createdAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
        pluginId: "opencode",
      );
      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "child",
            currentBranchName: "stale-child",
            currentGithubRepositoryIdentity: "stale/repository",
          ),
        ],
      );

      final changed = await repository.applyResolvedTargets(
        sessionsByProject: {projectId: await _storedSessions(database: db)},
        targetsByDirectory: const {
          "/project": PullRequestGithubDirectoryTarget(
            target: (githubRepositoryIdentity: repositoryIdentity, branchName: "main"),
          ),
          "/worktree": PullRequestGithubDirectoryTarget(
            target: (githubRepositoryIdentity: repositoryIdentity, branchName: "feature/current"),
          ),
        },
      );

      final projectRoot = await db.sessionDao.getSession(sessionId: "project-root");
      final worktreeRoot = await db.sessionDao.getSession(sessionId: "worktree-root");
      final child = await db.sessionDao.getSession(sessionId: "child");
      expect(projectRoot?.branchName, "created-main");
      expect(projectRoot?.currentBranchName, "main");
      expect(projectRoot?.currentGithubRepositoryIdentity, repositoryIdentity);
      expect(worktreeRoot?.branchName, "created-worktree");
      expect(worktreeRoot?.currentBranchName, "feature/current");
      expect(child?.currentBranchName, isNull);
      expect(child?.currentGithubRepositoryIdentity, isNull);
      expect(changed, {projectId});
    });

    test("branch-only and detached targets clear stale selected PRs", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "previous",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: "previous",
        number: 1,
      );

      final branchOnlyChanged = await repository.applyResolvedTargets(
        sessionsByProject: {projectId: await _storedSessions(database: db)},
        targetsByDirectory: const {
          "/project": PullRequestLocalBranchDirectoryTarget(branchName: "local-only"),
        },
      );
      final branchOnly = await db.sessionDao.getSession(sessionId: "project-root");
      expect(branchOnly?.currentBranchName, "local-only");
      expect(branchOnly?.currentGithubRepositoryIdentity, isNull);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: projectId), isEmpty);
      expect(branchOnlyChanged, {projectId});

      final detachedChanged = await repository.applyResolvedTargets(
        sessionsByProject: {projectId: await _storedSessions(database: db)},
        targetsByDirectory: const {
          "/project": PullRequestNoBranchDirectoryTarget(
            reason: PullRequestNoBranchReason.detachedHead,
          ),
        },
      );
      final detached = await db.sessionDao.getSession(sessionId: "project-root");
      expect(detached?.currentBranchName, isNull);
      expect(detached?.branchName, "created-main");
      expect(detachedChanged, {projectId});
      expect((await db.projectsDao.getProject(projectId: projectId))?.prCacheGithubLogin, isNull);
    });

    test("branch resolution failure preserves the captured current scope", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "preserved",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: "preserved",
        number: 1,
      );

      final changed = await repository.applyResolvedTargets(
        sessionsByProject: {projectId: await _storedSessions(database: db)},
        targetsByDirectory: {
          "/project": PullRequestBranchResolutionFailed(
            error: PullRequestTargetResolutionException(
              innerError: StateError("failed"),
              innerStackTrace: StackTrace.current,
            ),
          ),
        },
      );

      final session = await db.sessionDao.getSession(sessionId: "project-root");
      expect(session?.currentBranchName, "preserved");
      expect(session?.currentGithubRepositoryIdentity, repositoryIdentity);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: projectId), hasLength(1));
      expect(changed, isEmpty);
    });

    test("clears stale scope when a captured session otherwise matches but its directory moved", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "preserved",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: "preserved",
        number: 1,
      );
      final captured = await _storedSessions(database: db);
      await db.sessionDao.updateObservedSessionProjection(
        sessionId: "project-root",
        directory: "/moved",
        catalogTitle: null,
        updateCatalogTitle: false,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      final changed = await repository.applyResolvedTargets(
        sessionsByProject: {projectId: captured},
        targetsByDirectory: const {
          "/project": PullRequestGithubDirectoryTarget(
            target: (githubRepositoryIdentity: repositoryIdentity, branchName: "preserved"),
          ),
        },
      );

      final session = await db.sessionDao.getSession(sessionId: "project-root");
      expect(session?.directory, "/moved");
      expect(session?.currentBranchName, isNull);
      expect(session?.currentGithubRepositoryIdentity, isNull);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: projectId), isEmpty);
      expect(changed, {projectId});
    });

    test("prepares the verified account without fabricating missing projects", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "main",
        repositoryIdentity: repositoryIdentity,
        githubLogin: "previous-account",
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: "previous-account",
        branchName: "main",
        number: 1,
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: "main",
        number: 2,
      );

      final changed = await repository.prepareScopedRefresh(
        projectIds: {projectId, "missing"},
        verifiedGithubLogin: verifiedGithubLogin,
      );

      final rows = await db.pullRequestDao.getPrsByProjectId(projectId: projectId);
      expect(rows.map((row) => row.prNumber), [2]);
      expect((await db.projectsDao.getProject(projectId: projectId))?.prCacheGithubLogin, "octocat");
      expect(await db.projectsDao.getProject(projectId: "missing"), isNull);
      expect(changed, {projectId});
    });

    test("replacement applies only while account and exact target scope match", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "main",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      final selected = _selectedPullRequest(
        repositoryIdentity: repositoryIdentity,
        branchName: "main",
        number: 42,
      );

      final applied = await repository.replaceScopedPullRequests(
        projectId: projectId,
        verifiedGithubLogin: verifiedGithubLogin,
        capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
        targetSelections: [selected],
        lastCheckedAt: 2,
      );
      expect(applied, isA<PullRequestReplacementApplied>());
      expect((applied as PullRequestReplacementApplied).changed, isTrue);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: projectId), hasLength(1));

      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "project-root",
            currentBranchName: "switched",
            currentGithubRepositoryIdentity: repositoryIdentity,
          ),
        ],
      );
      final stale = await repository.replaceScopedPullRequests(
        projectId: projectId,
        verifiedGithubLogin: verifiedGithubLogin,
        capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
        targetSelections: [selected],
        lastCheckedAt: 3,
      );
      expect(stale, isA<PullRequestReplacementScopeChanged>());
      expect((await db.pullRequestDao.getPrsByProjectId(projectId: projectId)).single.prNumber, 42);
    });

    test("replacement rejects a query captured before a root directory moved", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "main",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      await _insertPullRequest(
        database: db,
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: "main",
        number: 1,
      );
      final selected = _selectedPullRequest(
        repositoryIdentity: repositoryIdentity,
        branchName: "main",
        number: 42,
      );
      await db.sessionDao.updateObservedSessionProjection(
        sessionId: "project-root",
        directory: "/moved",
        catalogTitle: null,
        updateCatalogTitle: false,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      final stale = await repository.replaceScopedPullRequests(
        projectId: projectId,
        verifiedGithubLogin: verifiedGithubLogin,
        capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
        targetSelections: [selected],
        lastCheckedAt: 3,
      );

      expect(stale, isA<PullRequestReplacementScopeChanged>());
      expect((await db.pullRequestDao.getPrsByProjectId(projectId: projectId)).single.prNumber, 1);
    });

    test("complete no-match clears and duplicate target outcomes are rejected", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      await _setScopeAndLogin(
        database: db,
        branchName: "main",
        repositoryIdentity: repositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      final selected = _selectedPullRequest(
        repositoryIdentity: repositoryIdentity,
        branchName: "main",
        number: 42,
      );
      await repository.replaceScopedPullRequests(
        projectId: projectId,
        verifiedGithubLogin: verifiedGithubLogin,
        capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
        targetSelections: [selected],
        lastCheckedAt: 2,
      );

      final cleared = await repository.replaceScopedPullRequests(
        projectId: projectId,
        verifiedGithubLogin: verifiedGithubLogin,
        capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
        targetSelections: [PullRequestTargetUnmatched(target: selected.target)],
        lastCheckedAt: 3,
      );
      expect((cleared as PullRequestReplacementApplied).changed, isTrue);
      expect(await db.pullRequestDao.getPrsByProjectId(projectId: projectId), isEmpty);

      await expectLater(
        repository.replaceScopedPullRequests(
          projectId: projectId,
          verifiedGithubLogin: verifiedGithubLogin,
          capturedRootDirectoriesBySessionId: const {"project-root": "/project"},
          targetSelections: [
            selected,
            PullRequestTargetUnmatched(target: selected.target),
          ],
          lastCheckedAt: 4,
        ),
        throwsArgumentError,
      );
    });

    test("local target application rolls back session scope when cleanup fails", () async {
      await _insertRoot(
        database: db,
        sessionId: "project-root",
        worktreePath: null,
        creationBranch: "created-main",
      );
      final failingRepository = _repository(
        database: db,
        pullRequestDao: _FailingPullRequestDao(db),
      );

      await expectLater(
        failingRepository.applyResolvedTargets(
          sessionsByProject: {projectId: await _storedSessions(database: db)},
          targetsByDirectory: const {
            "/project": PullRequestGithubDirectoryTarget(
              target: (githubRepositoryIdentity: repositoryIdentity, branchName: "main"),
            ),
          },
        ),
        throwsStateError,
      );

      final session = await db.sessionDao.getSession(sessionId: "project-root");
      expect(session?.currentBranchName, isNull);
      expect(session?.currentGithubRepositoryIdentity, isNull);
    });
  });
}

PullRequestRepository _repository({
  required AppDatabase database,
  required PullRequestDao pullRequestDao,
}) {
  return PullRequestRepository(
    database: database,
    pullRequestDao: pullRequestDao,
    projectsDao: database.projectsDao,
    sessionDao: database.sessionDao,
  );
}

Future<void> _insertRoot({
  required AppDatabase database,
  required String sessionId,
  required String? worktreePath,
  required String creationBranch,
}) {
  return database.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: "X",
    isDedicated: worktreePath != null,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: creationBranch,
    baseBranch: "main",
    baseCommit: "abc123",
    lastAgent: null,
    lastAgentModel: null,
  );
}

Future<List<StoredSession>> _storedSessions({required AppDatabase database}) async {
  final rows = await database.sessionDao.getSessionsByProject(projectId: "X");
  return rows.map((row) => row.toStoredSession()).toList(growable: false);
}

Future<void> _setScopeAndLogin({
  required AppDatabase database,
  required String branchName,
  required String repositoryIdentity,
  required String githubLogin,
}) async {
  await database.sessionDao.updatePullRequestScopes(
    updates: [
      (
        sessionId: "project-root",
        currentBranchName: branchName,
        currentGithubRepositoryIdentity: repositoryIdentity,
      ),
    ],
  );
  await database.projectsDao.setPrCacheGithubLogin(
    projectId: "X",
    githubLogin: githubLogin,
  );
}

Future<void> _insertPullRequest({
  required AppDatabase database,
  required String repositoryIdentity,
  required String githubLogin,
  required String branchName,
  required int number,
}) {
  return database.pullRequestDao.upsertPr(
    pullRequest: PullRequestDto(
      projectId: "X",
      githubRepositoryIdentity: repositoryIdentity,
      githubLogin: githubLogin,
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

PullRequestTargetSelected _selectedPullRequest({
  required String repositoryIdentity,
  required String branchName,
  required int number,
}) {
  return PullRequestTargetSelected(
    target: (
      githubRepositoryIdentity: repositoryIdentity,
      branchName: branchName,
    ),
    number: number,
    url: "https://github.com/$repositoryIdentity/pull/$number",
    title: "Test PR $number",
    createdAt: DateTime.fromMillisecondsSinceEpoch(number, isUtc: true),
    state: PrState.open,
    mergeableStatus: PrMergeableStatus.mergeable,
    reviewDecision: PrReviewDecision.reviewRequired,
    checkStatus: PrCheckStatus.success,
  );
}

final class _FailingPullRequestDao extends PullRequestDao {
  _FailingPullRequestDao(super.database);

  @override
  Future<void> deletePrsOutsideTargets({
    required String projectId,
    required Set<PullRequestPersistedTarget> targets,
  }) {
    throw StateError("scope cleanup failed");
  }
}
