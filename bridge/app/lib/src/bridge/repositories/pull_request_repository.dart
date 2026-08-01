import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/pull_request_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/database.dart";
import "../../api/database/tables/pull_requests_table.dart";
import "../../repositories/models/pull_request_selection.dart";
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

  Future<bool> prepareScopedRefresh({
    required String projectId,
    required String githubRepositoryIdentity,
    required VerifiedGithubLogin verifiedGithubLogin,
    required List<StoredSession> sessions,
  }) async {
    return _database.transaction(() async {
      final sessionIds = sessions.map((session) => session.id).toList(growable: false);
      final before = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
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
        branchNames: _rootBranchNames(sessions: sessions),
      );
      final after = await _pullRequestDao.getPrsByPersistedScopeSessionIds(sessionIds: sessionIds);
      return !_sameVisiblePullRequests(before: before, after: after);
    });
  }

  Future<bool> clearScopedRefresh({
    required String projectId,
    required List<StoredSession> sessions,
  }) async {
    return _database.transaction(() async {
      final before = await _pullRequestDao.getPrsByPersistedScopeSessionIds(
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

  Future<bool> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async {
    final targets = targetSelections.map((selection) => selection.target).toSet();
    if (targets.length != targetSelections.length) {
      throw ArgumentError.value(
        targetSelections,
        "targetSelections",
        "Expected exactly one result per pull request target",
      );
    }
    final replacements = [
      for (final selection in targetSelections)
        if (selection case final PullRequestTargetSelected pullRequest)
          PullRequestDto(
            projectId: projectId,
            githubRepositoryIdentity: pullRequest.target.githubRepositoryIdentity,
            githubLogin: verifiedGithubLogin.login,
            branchName: pullRequest.target.branchName,
            prNumber: pullRequest.number,
            url: pullRequest.url,
            title: pullRequest.title,
            state: pullRequest.state,
            mergeableStatus: pullRequest.mergeableStatus,
            reviewDecision: pullRequest.reviewDecision,
            checkStatus: pullRequest.checkStatus,
            lastCheckedAt: lastCheckedAt,
            createdAt: pullRequest.createdAt.millisecondsSinceEpoch,
          ),
    ];
    return _database.transaction(() async {
      final previous = await _pullRequestDao.getPrsByProjectId(projectId: projectId);
      final changed = !_sameSelectedPullRequests(previous: previous, replacements: replacements);
      await _pullRequestDao.deletePrsByProjectId(projectId: projectId);
      for (final replacement in replacements) {
        await _pullRequestDao.upsertPr(pullRequest: replacement);
      }
      return changed;
    });
  }

  bool _sameVisiblePullRequests({
    required Map<String, List<PullRequestDto>> before,
    required Map<String, List<PullRequestDto>> after,
  }) {
    final beforeKeys = _visiblePullRequestKeys(before);
    final afterKeys = _visiblePullRequestKeys(after);
    return beforeKeys.length == afterKeys.length && beforeKeys.containsAll(afterKeys);
  }

  bool _sameSelectedPullRequests({
    required List<PullRequestDto> previous,
    required List<PullRequestDto> replacements,
  }) {
    if (previous.length != replacements.length) return false;
    final previousByKey = {
      for (final pullRequest in previous) (pullRequest.githubRepositoryIdentity, pullRequest.prNumber): pullRequest,
    };
    for (final replacement in replacements) {
      final existing = previousByKey[(replacement.githubRepositoryIdentity, replacement.prNumber)];
      if (existing == null ||
          existing.githubLogin != replacement.githubLogin ||
          existing.branchName != replacement.branchName ||
          existing.url != replacement.url ||
          existing.title != replacement.title ||
          existing.state != replacement.state ||
          existing.mergeableStatus != replacement.mergeableStatus ||
          existing.reviewDecision != replacement.reviewDecision ||
          existing.checkStatus != replacement.checkStatus ||
          existing.createdAt != replacement.createdAt) {
        return false;
      }
    }
    return true;
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

  Set<String> _rootBranchNames({required List<StoredSession> sessions}) {
    return {
      for (final session in sessions)
        if (session.parentSessionId == null)
          if (session.branchName case final branchName? when branchName.isNotEmpty) branchName,
    };
  }
}
