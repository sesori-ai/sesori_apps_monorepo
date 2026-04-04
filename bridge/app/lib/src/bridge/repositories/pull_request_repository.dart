import "../api/database/daos/pull_request_dao.dart";
import "../api/database/tables/pull_requests_table.dart";

class PullRequestRepository {
  final PullRequestDao _pullRequestDao;

  PullRequestRepository({required PullRequestDao pullRequestDao}) : _pullRequestDao = pullRequestDao;

  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) async {
    return _pullRequestDao.getActivePrsByProjectId(projectId: projectId);
  }

  Future<void> upsertPullRequest({required PullRequestDto record}) async {
    await _pullRequestDao.upsertPr(
      projectId: record.projectId,
      branchName: record.branchName,
      prNumber: record.prNumber,
      url: record.url,
      title: record.title,
      state: record.state,
      mergeableStatus: record.mergeableStatus,
      reviewDecision: record.reviewDecision,
      checkStatus: record.checkStatus,
      lastCheckedAt: record.lastCheckedAt,
      createdAt: record.createdAt,
    );
  }
}
