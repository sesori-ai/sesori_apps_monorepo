import "package:drift/drift.dart";

import "../../../persistence/database.dart";
import "../../../persistence/tables/session_table.dart";
import "../tables/pull_requests_table.dart";

part "pull_request_dao.g.dart";

@DriftAccessor(tables: [PullRequestsTable, SessionTable])
class PullRequestDao extends DatabaseAccessor<AppDatabase> with _$PullRequestDaoMixin {
  PullRequestDao(super.attachedDatabase);

  Future<void> upsertPr({required PullRequestDto pullRequest}) async {
    await into(pullRequestsTable).insertOnConflictUpdate(pullRequest);
  }

  Future<List<PullRequestDto>> getPrsByProjectId({
    required String projectId,
  }) async {
    return (select(pullRequestsTable)..where((t) => t.projectId.equals(projectId))).get();
  }

  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({
    required List<String> sessionIds,
  }) async {
    if (sessionIds.isEmpty) {
      return <String, List<PullRequestDto>>{};
    }

    final query = select(pullRequestsTable).join([
      innerJoin(
        sessionTable,
        pullRequestsTable.projectId.equalsExp(sessionTable.projectId) &
            pullRequestsTable.branchName.equalsExp(sessionTable.branchName),
      ),
    ])..where(sessionTable.sessionId.isIn(sessionIds));

    final joinedRows = await query.get();
    final groupedBySessionId = <String, List<PullRequestDto>>{};

    for (final row in joinedRows) {
      final session = row.readTable(sessionTable);
      final pr = row.readTable(pullRequestsTable);
      groupedBySessionId.putIfAbsent(session.sessionId, () => <PullRequestDto>[]).add(pr);
    }

    return groupedBySessionId;
  }

  Future<List<PullRequestDto>> getActivePrsByProjectId({
    required String projectId,
  }) async {
    return (select(
      pullRequestsTable,
    )..where((t) => t.projectId.equals(projectId) & t.state.collate(Collate.noCase).equals("OPEN"))).get();
  }

  Future<void> deletePr({
    required String projectId,
    required int prNumber,
  }) async {
    await (delete(
      pullRequestsTable,
    )..where((t) => t.projectId.equals(projectId) & t.prNumber.equals(prNumber))).go();
  }
}
