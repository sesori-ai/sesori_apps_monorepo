import "../api/database/daos/pull_request_dao.dart";
import "../api/database/tables/pull_requests_table.dart";
import "../api/gh_pull_request.dart";

class PullRequestRepository {
  final PullRequestDao _pullRequestDao;

  PullRequestRepository({required PullRequestDao pullRequestDao}) : _pullRequestDao = pullRequestDao;

  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) async {
    return _pullRequestDao.getActivePrsByProjectId(projectId: projectId);
  }

  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) {
    return _pullRequestDao.getPrsBySessionIds(sessionIds: sessionIds);
  }

  Future<bool> hasChanged({
    required String projectId,
    required int prNumber,
    required GhPullRequest pr,
  }) async {
    final existingPrs = await _pullRequestDao.getPrsByProjectId(projectId: projectId);
    final existing = existingPrs.where((it) => it.prNumber == prNumber).firstOrNull;
    if (existing == null) {
      return true;
    }

    return existing.prNumber != pr.number ||
        existing.url != pr.url ||
        existing.title != pr.title ||
        existing.state != pr.state.name.toUpperCase() ||
        existing.mergeableStatus != pr.mergeable.name.toUpperCase() ||
        existing.reviewDecision != pr.reviewDecision.name.toUpperCase() ||
        existing.checkStatus != pr.statusCheckRollup.name.toUpperCase();
  }

  Future<void> upsertFromGhPr({
    required String projectId,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) async {
    await _pullRequestDao.upsertPr(
      pullRequest: PullRequestDto(
        projectId: projectId,
        branchName: pr.headRefName,
        prNumber: pr.number,
        url: pr.url,
        title: pr.title,
        state: pr.state.name.toUpperCase(),
        mergeableStatus: pr.mergeable.name.toUpperCase(),
        reviewDecision: pr.reviewDecision.name.toUpperCase(),
        checkStatus: pr.statusCheckRollup.name.toUpperCase(),
        lastCheckedAt: lastCheckedAt,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> upsertPullRequest({required PullRequestDto record}) async {
    await _pullRequestDao.upsertPr(pullRequest: record);
  }
}
