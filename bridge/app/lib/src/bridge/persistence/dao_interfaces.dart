import "tables/session_table.dart";
import "database.dart";

abstract interface class SessionDaoLike {
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds});

  Future<List<SessionDto>> getSessionsByProject({required String projectId});
}

abstract interface class PullRequestDaoLike {
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
  });

  Future<List<PullRequestsTableData>> getPrsByProjectId({required String projectId});

  Future<Map<String, PullRequestsTableData>> getPrsBySessionIds({
    required List<String> sessionIds,
  });

  Future<List<PullRequestsTableData>> getActivePrsByProjectId({
    required String projectId,
  });

  Future<void> deletePr({required String projectId, required String branchName});
}
