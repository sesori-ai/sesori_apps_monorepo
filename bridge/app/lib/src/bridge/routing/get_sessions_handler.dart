import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/database.dart";
import "../persistence/tables/session_table.dart";
import "plugin_session_mapper.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Merges archive status from the database with plugin session data.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final BridgePlugin _plugin;
  final SessionDaoLike _sessionDao;
  final PullRequestDaoLike _prDao;
  final Future<void> Function({required String projectId, required String projectPath})? _onSessionListRequested;

  GetSessionsHandler(
    this._plugin,
    SessionDaoLike sessionDao,
    PullRequestDaoLike prDao, {
    Future<void> Function({required String projectId, required String projectPath})? onSessionListRequested,
  }) : _sessionDao = sessionDao,
       _prDao = prDao,
       _onSessionListRequested = onSessionListRequested,
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

    final sessionIdsForPr = mergedSessions.map((s) => s.id).toList();
    final prsBySessionId = await _prDao.getPrsBySessionIds(sessionIds: sessionIdsForPr);

    final mergedSessionsWithPr = mergedSessions.map((session) {
      final pr = prsBySessionId[session.id];
      if (pr == null) {
        return session;
      }
      return session.copyWith(
        pullRequest: PullRequestInfo(
          number: pr.prNumber,
          url: pr.url,
          title: pr.title,
          state: pr.state,
          mergeableStatus: pr.mergeableStatus,
          reviewDecision: pr.reviewDecision,
          checkStatus: pr.checkStatus,
        ),
      );
    }).toList();

    final response = SessionListResponse(items: mergedSessionsWithPr);
    final callback = _onSessionListRequested;
    if (callback != null) {
      unawaited(callback(projectId: projectId, projectPath: projectId));
    }
    return response;
  }
}

/// Interface for session DAO operations needed by [GetSessionsHandler].
abstract interface class SessionDaoLike {
  Future<Map<String, SessionDto>> getSessionsByIds({required List<String> sessionIds});

  Future<List<SessionDto>> getSessionsByProject({required String projectId});
}

/// Interface for pull request DAO operations.
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
