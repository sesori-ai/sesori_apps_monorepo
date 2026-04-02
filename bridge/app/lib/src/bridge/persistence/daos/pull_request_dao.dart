import "package:drift/drift.dart";

import "../../routing/get_sessions_handler.dart";
import "../database.dart";
import "../tables/pull_requests_table.dart";
import "../tables/session_table.dart";

part "pull_request_dao.g.dart";

@DriftAccessor(tables: [PullRequestsTable, SessionTable])
class PullRequestDao extends DatabaseAccessor<AppDatabase> with _$PullRequestDaoMixin implements PullRequestDaoLike {
  PullRequestDao(super.attachedDatabase);

  @override
  Future<void> upsertPr({
    required String projectId,
    required String branchName,
    required int prNumber,
    required String url,
    required String title,
    required String state,
    required String? mergeableStatus,
    required String? reviewDecision,
    required String? checkStatus,
    required String? sessionId,
    required int lastCheckedAt,
    required int createdAt,
  }) async {
    await into(pullRequestsTable).insertOnConflictUpdate(
      PullRequestsTableCompanion(
        projectId: Value(projectId),
        branchName: Value(branchName),
        prNumber: Value(prNumber),
        url: Value(url),
        title: Value(title),
        state: Value(state),
        mergeableStatus: Value(mergeableStatus),
        reviewDecision: Value(reviewDecision),
        checkStatus: Value(checkStatus),
        sessionId: Value(sessionId),
        lastCheckedAt: Value(lastCheckedAt),
        createdAt: Value(createdAt),
      ),
    );
  }

  @override
  Future<List<PullRequestsTableData>> getPrsByProjectId({
    required String projectId,
  }) async {
    return (select(pullRequestsTable)..where((t) => t.projectId.equals(projectId))).get();
  }

  @override
  Future<Map<String, PullRequestsTableData>> getPrsBySessionIds({
    required List<String> sessionIds,
  }) async {
    if (sessionIds.isEmpty) {
      return <String, PullRequestsTableData>{};
    }

    final prs = await (select(pullRequestsTable)..where((t) => t.sessionId.isIn(sessionIds))).get();

    return <String, PullRequestsTableData>{
      for (final pr in prs)
        if (pr.sessionId != null) pr.sessionId!: pr,
    };
  }

  @override
  Future<List<PullRequestsTableData>> getActivePrsByProjectId({
    required String projectId,
  }) async {
    return (select(
      pullRequestsTable,
    )..where((t) => t.projectId.equals(projectId) & t.state.collate(Collate.noCase).equals("OPEN"))).get();
  }

  @override
  Future<void> deletePr({
    required String projectId,
    required String branchName,
  }) async {
    await (delete(
      pullRequestsTable,
    )..where((t) => t.projectId.equals(projectId) & t.branchName.equals(branchName))).go();
  }
}
