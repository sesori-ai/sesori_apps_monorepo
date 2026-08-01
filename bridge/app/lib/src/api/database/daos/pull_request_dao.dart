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
  }) {
    return _getPrsBySessionIds(
      sessionIds: sessionIds,
      verifiedGithubLogin: verifiedGithubLogin,
    );
  }

  Future<Map<String, List<PullRequestDto>>> getPrsByPersistedScopeSessionIds({
    required List<String> sessionIds,
  }) {
    return _getPrsBySessionIds(
      sessionIds: sessionIds,
      verifiedGithubLogin: null,
    );
  }

  Future<Map<String, List<PullRequestDto>>> _getPrsBySessionIds({
    required List<String> sessionIds,
    required String? verifiedGithubLogin,
  }) async {
    if (sessionIds.isEmpty) {
      return <String, List<PullRequestDto>>{};
    }

    final readLoginScope = verifiedGithubLogin == null
        ? const Constant(true)
        : pullRequestsTable.githubLogin.equals(verifiedGithubLogin) &
              projectsTable.prCacheGithubLogin.equals(verifiedGithubLogin);
    final query =
        select(pullRequestsTable).join([
          innerJoin(
            sessionTable,
            pullRequestsTable.projectId.equalsExp(sessionTable.projectId) &
                pullRequestsTable.githubRepositoryIdentity.equalsExp(
                  sessionTable.currentGithubRepositoryIdentity,
                ) &
                pullRequestsTable.branchName.equalsExp(sessionTable.currentBranchName),
          ),
          innerJoin(
            projectsTable,
            projectsTable.projectId.equalsExp(sessionTable.projectId) &
                projectsTable.prCacheGithubLogin.equalsExp(pullRequestsTable.githubLogin),
          ),
        ])..where(
          sessionTable.sessionId.isIn(sessionIds) & sessionTable.parentSessionId.isNull() & readLoginScope,
        );

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
          (table) =>
              table.projectId.equals(projectId) &
              table.githubRepositoryIdentity.equals(githubRepositoryIdentity) &
              table.githubLogin.equals(githubLogin) &
              table.state.equals(PrState.open.name),
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
          (table) =>
              table.projectId.equals(projectId) &
              table.githubRepositoryIdentity.equals(githubRepositoryIdentity) &
              table.prNumber.equals(prNumber),
        ))
        .go();
  }

  Future<void> deletePrsOutsideScope({
    required String projectId,
    required String githubRepositoryIdentity,
    required String githubLogin,
    required Set<String> branchNames,
  }) async {
    await (delete(pullRequestsTable)..where(
          (table) {
            final branchIsOutsideScope = branchNames.isEmpty
                ? const Constant(true)
                : table.branchName.isIn(branchNames).not();
            return table.projectId.equals(projectId) &
                (table.githubRepositoryIdentity.equals(githubRepositoryIdentity).not() |
                    table.githubLogin.equals(githubLogin).not() |
                    branchIsOutsideScope);
          },
        ))
        .go();
  }

  Future<void> deletePrsByProjectId({required String projectId}) async {
    await (delete(pullRequestsTable)..where((table) => table.projectId.equals(projectId))).go();
  }
}
