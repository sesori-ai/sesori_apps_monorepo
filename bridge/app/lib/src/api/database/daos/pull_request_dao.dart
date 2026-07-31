import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../database.dart";
import "../tables/projects_table.dart";
import "../tables/pull_requests_table.dart";
import "../tables/session_table.dart";

part "pull_request_dao.g.dart";

@DriftAccessor(tables: [ProjectsTable, PullRequestsTable, SessionTable])
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
    required String verifiedGithubLogin,
  }) async {
    if (sessionIds.isEmpty) {
      return <String, List<PullRequestDto>>{};
    }

    final query = select(pullRequestsTable).join([
      innerJoin(
        sessionTable,
        pullRequestsTable.projectId.equalsExp(sessionTable.projectId) &
            pullRequestsTable.githubRepositoryIdentity.equalsExp(
              sessionTable.currentGithubRepositoryIdentity,
            ) &
            pullRequestsTable.branchName.equalsExp(sessionTable.currentBranchName) &
            pullRequestsTable.githubLogin.equals(verifiedGithubLogin),
      ),
      innerJoin(
        projectsTable,
        projectsTable.projectId.equalsExp(sessionTable.projectId) &
            projectsTable.prCacheGithubLogin.equals(verifiedGithubLogin),
      ),
    ])..where(sessionTable.sessionId.isIn(sessionIds) & sessionTable.parentSessionId.isNull());

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
    required String githubRepositoryIdentity,
    required String githubLogin,
  }) async {
    return (select(
          pullRequestsTable,
        )..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.githubRepositoryIdentity.equals(githubRepositoryIdentity) &
              t.githubLogin.equals(githubLogin) &
              t.state.equals(PrState.open.name),
        ))
        .get();
  }

  Future<void> deletePr({
    required String projectId,
    required String githubRepositoryIdentity,
    required int prNumber,
  }) async {
    await (delete(
          pullRequestsTable,
        )..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.githubRepositoryIdentity.equals(githubRepositoryIdentity) &
              t.prNumber.equals(prNumber),
        ))
        .go();
  }

  Future<void> deletePrsOutsideRepositoryScope({
    required String projectId,
    required String githubRepositoryIdentity,
  }) async {
    await (delete(pullRequestsTable)..where(
          (table) =>
              table.projectId.equals(projectId) & table.githubRepositoryIdentity.equals(githubRepositoryIdentity).not(),
        ))
        .go();
  }

  Future<void> deletePrsByProjectId({required String projectId}) async {
    await (delete(pullRequestsTable)..where((table) => table.projectId.equals(projectId))).go();
  }
}
