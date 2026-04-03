import "../api/database/tables/pull_requests_table.dart";
import "tables/session_table.dart";

abstract interface class SessionDaoLike {
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds});

  Future<List<SessionDto>> getSessionsByProject({required String projectId});
}

abstract interface class PullRequestDaoLike {
  Future<Map<String, PullRequestDto>> getPrsBySessionIds({required List<String> sessionIds});
}
