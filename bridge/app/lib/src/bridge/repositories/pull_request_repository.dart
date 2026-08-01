import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/pull_request_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/database.dart";
import "../../api/database/tables/pull_requests_table.dart";
import "../api/gh_pull_request.dart";
import "models/stored_session.dart";
import "models/verified_github_login.dart";

class PullRequestRepository {
  final AppDatabase _database;
  final PullRequestDao _pullRequestDao;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;

  PullRequestRepository({
    required AppDatabase database,
    required PullRequestDao pullRequestDao,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
  }) : _database = database,
       _pullRequestDao = pullRequestDao,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao;

  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({
    required String projectId,
    required String githubRepositoryIdentity,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async {
    return _pullRequestDao.getActivePrsByProjectId(
      projectId: projectId,
      githubRepositoryIdentity: githubRepositoryIdentity,
      githubLogin: verifiedGithubLogin.login,
    );
  }

  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) {
    return _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
  }

  Future<bool> prepareScopedRefresh({
    required String projectId,
    required String githubRepositoryIdentity,
    required VerifiedGithubLogin verifiedGithubLogin,
    required List<StoredSession> sessions,
  }) async {
    return _database.transaction(() async {
      final sessionIds = sessions.map((session) => session.id).toList(growable: false);
      final before = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
      await _projectsDao.setPrCacheGithubLogin(
        projectId: projectId,
        githubLogin: verifiedGithubLogin.login,
      );
      await _sessionDao.updatePullRequestScopes(
        updates: [
          for (final session in sessions)
            (
              sessionId: session.id,
              currentBranchName: session.parentSessionId == null ? session.branchName : null,
              currentGithubRepositoryIdentity: session.parentSessionId == null ? githubRepositoryIdentity : null,
            ),
        ],
      );
      await _pullRequestDao.deletePrsOutsideScope(
        projectId: projectId,
        githubRepositoryIdentity: githubRepositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
      );
      final after = await _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
      return !_sameVisiblePullRequests(before: before, after: after);
    });
  }

  Future<bool> clearScopedRefresh({
    required String projectId,
    required List<StoredSession> sessions,
  }) async {
    return _database.transaction(() async {
      final before = await _pullRequestDao.getPrsBySessionIds(
        sessionIds: sessions.map((session) => session.id).toList(growable: false),
      );
      await _projectsDao.setPrCacheGithubLogin(projectId: projectId, githubLogin: null);
      await _sessionDao.updatePullRequestScopes(
        updates: [
          for (final session in sessions)
            (
              sessionId: session.id,
              currentBranchName: null,
              currentGithubRepositoryIdentity: null,
            ),
        ],
      );
      await _pullRequestDao.deletePrsByProjectId(projectId: projectId);
      return before.values.any((pullRequests) => pullRequests.isNotEmpty);
    });
  }

  bool hasChangedFromExisting({
    required PullRequestDto? existing,
    required GhPullRequest pr,
  }) {
    if (existing == null) return true;

    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.branchName != pr.headRefName ||
        existing.state != pr.state ||
        existing.mergeableStatus != pr.mergeable ||
        existing.reviewDecision != pr.reviewDecision ||
        existing.checkStatus != pr.statusCheckRollup;
  }

  Future<void> upsertFromGhPr({
    required String projectId,
    required String githubRepositoryIdentity,
    required VerifiedGithubLogin verifiedGithubLogin,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) async {
    await _pullRequestDao.upsertPr(
      pullRequest: PullRequestDto(
        projectId: projectId,
        githubRepositoryIdentity: githubRepositoryIdentity,
        githubLogin: verifiedGithubLogin.login,
        branchName: pr.headRefName,
        prNumber: pr.number,
        url: pr.url,
        title: pr.title,
        state: pr.state,
        mergeableStatus: pr.mergeable,
        reviewDecision: pr.reviewDecision,
        checkStatus: pr.statusCheckRollup,
        lastCheckedAt: lastCheckedAt,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> upsertPullRequest({required PullRequestDto record}) async {
    // Defensive backstop: ensure the project row exists before inserting the PR.
    await _projectsDao.insertProjectsIfMissing(projectIds: [record.projectId]);
    await _pullRequestDao.upsertPr(pullRequest: record);
  }

  Future<void> deletePr({
    required String projectId,
    required String githubRepositoryIdentity,
    required int prNumber,
  }) async {
    await _pullRequestDao.deletePr(
      projectId: projectId,
      githubRepositoryIdentity: githubRepositoryIdentity,
      prNumber: prNumber,
    );
  }

  bool _sameVisiblePullRequests({
    required Map<String, List<PullRequestDto>> before,
    required Map<String, List<PullRequestDto>> after,
  }) {
    final beforeKeys = _visiblePullRequestKeys(before);
    final afterKeys = _visiblePullRequestKeys(after);
    return beforeKeys.length == afterKeys.length && beforeKeys.containsAll(afterKeys);
  }

  Set<({String sessionId, String repository, String login, int number})> _visiblePullRequestKeys(
    Map<String, List<PullRequestDto>> pullRequestsBySession,
  ) {
    return {
      for (final entry in pullRequestsBySession.entries)
        for (final pullRequest in entry.value)
          (
            sessionId: entry.key,
            repository: pullRequest.githubRepositoryIdentity,
            login: pullRequest.githubLogin,
            number: pullRequest.prNumber,
          ),
    };
  }
}
