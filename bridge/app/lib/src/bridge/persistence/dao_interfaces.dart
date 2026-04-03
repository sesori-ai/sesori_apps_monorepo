import "tables/session_table.dart";

abstract interface class SessionDaoLike {
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds});

  Future<List<SessionDto>> getSessionsByProject({required String projectId});
}
