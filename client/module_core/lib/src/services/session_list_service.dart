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
        data,
      ),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }

  List<Session> visibleSessions({
    required Iterable<Session> sessions,
    required bool showArchived,
    required Set<String> activeSessionIds,
    required Map<String, int?> lastUserInteractionAtBySessionId,
  }) {
    final visible = showArchived ? sessions : sessions.where((session) => session.time?.archived == null);
    return _sortSessions(
      sessions: visible,
      activeSessionIds: activeSessionIds,
      lastUserInteractionAtBySessionId: lastUserInteractionAtBySessionId,
    );
  }

  List<Session> upsertSession({required Iterable<Session> sessions, required Session session}) {
    return [
      ...sessions.where((existing) => existing.id != session.id),
      session,
    ];
  }

  List<Session> removeSession({required Iterable<Session> sessions, required String sessionId}) {
    return sessions.where((session) => session.id != sessionId).toList();
  }

  List<Session> _sortSessions({
    required Iterable<Session> sessions,
    required Set<String> activeSessionIds,
    required Map<String, int?> lastUserInteractionAtBySessionId,
  }) {
    return sessions.toList()..sort(
      (a, b) => _compareSessions(
        a: a,
        b: b,
        activeSessionIds: activeSessionIds,
        lastUserInteractionAtBySessionId: lastUserInteractionAtBySessionId,
      ),
    );
  }

  int _compareSessions({
    required Session a,
    required Session b,
    required Set<String> activeSessionIds,
    required Map<String, int?> lastUserInteractionAtBySessionId,
  }) {
    final aActive = activeSessionIds.contains(a.id);
    final bActive = activeSessionIds.contains(b.id);
    if (aActive != bActive) return aActive ? -1 : 1;
    if (!aActive) {
      return (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0);
    }

    final interactionCompare = _compareNullableDescending(
      a: _lastUserInteractionAt(
        session: a,
        lastUserInteractionAtBySessionId: lastUserInteractionAtBySessionId,
      ),
      b: _lastUserInteractionAt(
        session: b,
        lastUserInteractionAtBySessionId: lastUserInteractionAtBySessionId,
      ),
    );
    if (interactionCompare != 0) return interactionCompare;

    final titleCompare = switch ((a.title, b.title)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final aTitle?, final bTitle?) => aTitle.toLowerCase().compareTo(bTitle.toLowerCase()),
    };
    if (titleCompare != 0) return titleCompare;

    return a.id.compareTo(b.id);
  }

  int? _lastUserInteractionAt({
    required Session session,
    required Map<String, int?> lastUserInteractionAtBySessionId,
  }) {
    return lastUserInteractionAtBySessionId.containsKey(session.id)
        ? lastUserInteractionAtBySessionId[session.id]
        : session.lastUserInteractionAt;
  }

  int _compareNullableDescending({required int? a, required int? b}) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}
