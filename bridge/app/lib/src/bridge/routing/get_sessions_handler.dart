import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/tables/session_table.dart";
import "plugin_session_mapper.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Merges archive status from the database with plugin session data.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final BridgePlugin _plugin;
  final SessionDaoLike _sessionDao;

  GetSessionsHandler(
    this._plugin,
    SessionDaoLike sessionDao,
  ) : _sessionDao = sessionDao,
      super(
        HttpMethod.post,
        "/sessions",
        fromJson: SessionListRequest.fromJson,
      );

  @override
  Future<SessionListResponse> handle(
    RelayRequest request, {
    required SessionListRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    if (projectId.isEmpty) {
      throw buildErrorResponse(
        request,
        400,
        "missing project id in body",
      );
    }

    final start = body.start;
    final limit = body.limit;

    final pluginSessions = await _plugin.getSessions(
      projectId,
      start: start,
      limit: limit,
    );

    // Map plugin sessions to shared Session objects
    final sessions = pluginSessions.map((s) => s.toSharedSession()).toList();

    // Merge archive status from database
    final sessionIds = sessions.map((s) => s.id).toList();
    final dbSessions = await _sessionDao.getSessionsByIds(sessionIds: sessionIds);

    final mergedSessions = sessions.map((session) {
      final dbSession = dbSessions[session.id];
      if (dbSession != null) {
        // DB record exists: override archived time with database value (even if null)
        final currentTime = session.time;
        final mergedTime = currentTime != null
            ? currentTime.copyWith(archived: dbSession.archivedAt)
            : SessionTime(
                created: 0,
                updated: 0,
                archived: dbSession.archivedAt,
              );
        return session.copyWith(time: mergedTime);
      }
      // No DB record: keep plugin's time.archived
      return session;
    }).toList();

    return SessionListResponse(items: mergedSessions);
  }
}

/// Interface for session DAO operations needed by [GetSessionsHandler].
abstract interface class SessionDaoLike {
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds});
}
