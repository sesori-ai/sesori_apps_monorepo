import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";

@lazySingleton
class SessionListService {
  final ProjectRepository _repository;

  SessionListService({required ProjectRepository repository}) : _repository = repository;

  Future<ApiResponse<SessionListResponse>> listSessions({
    required String projectId,
    required bool waitForPrData,
  }) async {
    final response = await _repository.listSessions(
      projectId: projectId,
      waitForPrData: waitForPrData,
    );
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success(
        SessionListResponse(items: _sortSessions(data.items)),
      ),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }

  List<Session> visibleSessions({
    required Iterable<Session> sessions,
    required bool showArchived,
  }) {
    final visible = showArchived ? sessions : sessions.where((session) => session.time?.archived == null);
    return _sortSessions(visible);
  }

  List<Session> upsertSession({required Iterable<Session> sessions, required Session session}) {
    return _sortSessions([
      ...sessions.where((existing) => existing.id != session.id),
      session,
    ]);
  }

  List<Session> removeSession({required Iterable<Session> sessions, required String sessionId}) {
    return _sortSessions(sessions.where((session) => session.id != sessionId));
  }

  List<Session> _sortSessions(Iterable<Session> sessions) {
    return sessions.toList()..sort((a, b) => _compareSessionsByTitleAndId(a: a, b: b));
  }

  int _compareSessionsByTitleAndId({required Session a, required Session b}) {
    final titleCompare = switch ((a.title, b.title)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final aTitle?, final bTitle?) => aTitle.toLowerCase().compareTo(bTitle.toLowerCase()),
    };
    if (titleCompare != 0) return titleCompare;

    return a.id.compareTo(b.id);
  }
}
