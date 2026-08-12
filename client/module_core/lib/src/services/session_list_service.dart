import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "models/session_activity_info.dart";
import "session_activity_calculator.dart";

@lazySingleton
class SessionListService({
    required ProjectRepository repository,
    required SessionActivityCalculator activityCalculator,
  }) {
  final ProjectRepository _repository;
  final SessionActivityCalculator _activityCalculator;

  this : _repository = repository,
       _activityCalculator = activityCalculator;

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
    required Map<String, SessionActivityInfo> activityBySessionId,
  }) {
    final visible = showArchived ? sessions : sessions.where((session) => session.time?.archived == null);
    final running = <Session>[];
    final remaining = <Session>[];
    for (final session in visible) {
      final activity = activityBySessionId[session.id];
      if (activity != null && _activityCalculator.isRunning(activity: activity)) {
        running.add(session);
      } else {
        remaining.add(session);
      }
    }
    running.sort((a, b) => _compareSessionsByTitleAndId(a: a, b: b));
    return [...running, ..._sortSessions(remaining)];
  }

  List<Session> upsertSession({required Iterable<Session> sessions, required Session session}) {
    return _sortSessions([
      ...sessions.where((existing) => existing.id != session.id),
      session,
    ]);
  }

  /// Applies a `session.updated` catalog projection without treating its
  /// identity-gated PR fields as authoritative absence.
  ///
  /// Project-scoped `sessions.updated` events trigger a REST refresh that owns
  /// replacing or clearing PR metadata. Ordinary session updates may omit
  /// either field, so each omitted value retains its last identity-gated
  /// snapshot instead.
  List<Session> applySessionUpdatedEvent({
    required Iterable<Session> sessions,
    required Session existingSession,
    required Session session,
  }) {
    final merged = session.copyWith(
      pullRequest: session.pullRequest ?? existingSession.pullRequest,
      pullRequestHistory: session.pullRequestHistory.isEmpty
          ? existingSession.pullRequestHistory
          : session.pullRequestHistory,
    );
    return upsertSession(sessions: sessions, session: merged);
  }

  List<Session> removeSession({required Iterable<Session> sessions, required String sessionId}) {
    return _sortSessions(sessions.where((session) => session.id != sessionId));
  }

  List<Session> _sortSessions(Iterable<Session> sessions) {
    return sessions.toList()..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
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
