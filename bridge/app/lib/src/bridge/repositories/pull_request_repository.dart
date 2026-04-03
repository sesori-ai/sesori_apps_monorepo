import "../api/database/daos/pull_request_dao.dart";
import "../repositories/mappers/pull_request_mapper.dart";
import "../repositories/models/pull_request_record.dart";

abstract interface class PullRequestRepositoryLike {
  Future<List<PullRequestRecord>> getActivePullRequestsByProjectId({required String projectId});

  Future<void> upsertPullRequest({required PullRequestRecord record});
}

class PullRequestRepository implements PullRequestRepositoryLike {
  final PullRequestDao _pullRequestDao;

  PullRequestRepository({required PullRequestDao pullRequestDao}) : _pullRequestDao = pullRequestDao;

  @override
  Future<List<PullRequestRecord>> getActivePullRequestsByProjectId({required String projectId}) async {
    final prs = await _pullRequestDao.getActivePrsByProjectId(projectId: projectId);
    return prs.map(pullRequestRecordFromDto).toList(growable: false);
  }

  @override
  Future<void> upsertPullRequest({required PullRequestRecord record}) async {
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
