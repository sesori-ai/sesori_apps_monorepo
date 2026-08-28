import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "models/session_activity_info.dart";
import "models/session_list_item_state.dart";
import "session_activity_calculator.dart";

@lazySingleton
class SessionListService({
  required final ProjectRepository _repository,
  required final SessionActivityCalculator _activityCalculator,
}) {
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
    required Map<String, SessionListItemState> listStateBySessionId,
  }) {
    final projected = sessions.map(
      (session) => _mergeLiveListState(
        session: session,
        listState: listStateBySessionId[session.id],
      ),
    );
    final visible = showArchived ? projected : projected.where((session) => session.time?.archived == null);
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
    running.sort(
      (a, b) => _compareRunningSessions(
        a: a,
        b: b,
        listStateBySessionId: listStateBySessionId,
      ),
    );
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
      lastUserActivityAt: latestUserActivityAt(
        first: existingSession.lastUserActivityAt,
        second: session.lastUserActivityAt,
      ),
    );
    return upsertSession(sessions: sessions, session: merged);
  }

  List<Session> removeSession({required Iterable<Session> sessions, required String sessionId}) {
    return _sortSessions(sessions.where((session) => session.id != sessionId));
  }

  /// Projects a live user-activity marker into the row's displayed recency.
  ///
  /// REST session rows already fold this marker into `time.updated`, but a
  /// newer marker can arrive over SSE after the fetch. Keeping the live
  /// projection here ensures the row does not reorder on fresh activity while
  /// continuing to display its stale REST timestamp.
  Session _mergeLiveListState({
    required Session session,
    required SessionListItemState? listState,
  }) {
    final lastUserActivityAt = latestUserActivityAt(
      first: session.lastUserActivityAt,
      second: listState?.lastUserActivityAt,
    );
    final time = session.time;
    if (time == null || lastUserActivityAt == null || lastUserActivityAt <= time.updated) {
      if (lastUserActivityAt == session.lastUserActivityAt) return session;
      return session.copyWith(lastUserActivityAt: lastUserActivityAt);
    }
    return session.copyWith(
      time: time.copyWith(updated: lastUserActivityAt),
      lastUserActivityAt: lastUserActivityAt,
    );
  }

  List<Session> _sortSessions(Iterable<Session> sessions) {
    return sessions.toList()..sort((a, b) {
      final updatedCompare = (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0);
      return updatedCompare != 0 ? updatedCompare : a.id.compareTo(b.id);
    });
  }

  int _compareRunningSessions({
    required Session a,
    required Session b,
    required Map<String, SessionListItemState> listStateBySessionId,
  }) {
    final aActivityAt = listStateBySessionId[a.id]?.lastUserActivityAt ?? a.lastUserActivityAt ?? a.time?.updated ?? 0;
    final bActivityAt = listStateBySessionId[b.id]?.lastUserActivityAt ?? b.lastUserActivityAt ?? b.time?.updated ?? 0;
    final activityCompare = bActivityAt.compareTo(aActivityAt);
    return activityCompare != 0 ? activityCompare : a.id.compareTo(b.id);
  }
}
