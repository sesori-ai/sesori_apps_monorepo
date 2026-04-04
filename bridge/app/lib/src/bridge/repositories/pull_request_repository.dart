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
    await _pullRequestDao.upsertPr(pullRequest: record);
  }

  Future<void> deletePr({
    required String projectId,
    required int prNumber,
  }) async {
    await _pullRequestDao.deletePr(projectId: projectId, prNumber: prNumber);
  }
}
