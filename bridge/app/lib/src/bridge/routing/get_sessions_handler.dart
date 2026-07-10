import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/session_persistence_service.dart";
import "../services/session_unseen_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Merges archive status from the database with plugin session data.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final SessionRepository _sessionRepository;
  final PrSyncService _prSyncService;
  final SessionPersistenceService _sessionPersistenceService;
  final SessionUnseenService _sessionUnseenService;
  final Duration _prRefreshTimeout;

  GetSessionsHandler({
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    required SessionPersistenceService sessionPersistenceService,
    required SessionUnseenService sessionUnseenService,
    Duration prRefreshTimeout = const Duration(seconds: 5),
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       _sessionPersistenceService = sessionPersistenceService,
       _sessionUnseenService = sessionUnseenService,
       _prRefreshTimeout = prRefreshTimeout,
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

    // Captured BEFORE the fetch so the vanished-session reconcile only removes
    // rows that already existed when the snapshot was taken — a session created
    // concurrently (row inserted after this point) is kept.
    final fetchStartedAt = DateTime.now().millisecondsSinceEpoch;
    final sessions = await _sessionRepository.getSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
    );

    try {
      await _sessionPersistenceService.persistSessionsForProject(
        projectId: projectId,
        sessions: sessions,
      );
    } on Object catch (e, st) {
      Log.w("GetSessionsHandler: persistSessionsForProject failed for projectId=$projectId: $e\n$st");
    }

    if (start == null && limit == null && _sessionRepository.sessionListIsAuthoritative) {
      // Unpaginated + authoritative ⇒ `sessions` is the complete list, so rows
      // for sessions that no longer exist (deleted while the bridge was
      // offline) can be reconciled away. Skipped when the repository cannot
      // vouch for completeness (bridge-derived plugins): deleting against an
      // incomplete list would drop rows for sessions the backend simply hasn't
      // flushed yet. Fire-and-forget: the unseen service serializes, emits the
      // aggregate updates for other clients, and logs failures; the requesting
      // client already gets the fresh list below.
      unawaited(
        _sessionUnseenService.reconcileVanishedSessions(
          projectId: projectId,
          keepSessionIds: [for (final s in sessions) s.id],
          fetchStartedAt: fetchStartedAt,
        ),
      );
    }

    final prRefreshFuture = _triggerPrRefresh(projectId: projectId, sessions: sessions);

    if (body.waitForPrData) {
      try {
        await prRefreshFuture.timeout(_prRefreshTimeout);
        // Refresh succeeded within timeout — enrich the already-fetched sessions
        // with updated PR/CI metadata from the database (no extra plugin round-trip).
        final enrichedSessions = await _sessionRepository.enrichSessions(
          sessions: sessions,
        );
        return SessionListResponse(items: enrichedSessions);
      } catch (err, st) {
        Log.w(
          "PR refresh timed out after "
          "${_prRefreshTimeout.inSeconds}s for $projectId — "
          "returning current data; SSE will deliver updates when ready",
          err,
          st,
        );
      }
    } else {
      // Fire-and-forget: PR data will be available for the next request.
      unawaited(prRefreshFuture);
    }

    return SessionListResponse(items: sessions);
  }

  Future<void> _triggerPrRefresh({
    required String projectId,
    required List<Session> sessions,
  }) async {
    try {
      final projectPath = await _sessionRepository.getProjectPath(projectId: projectId);
      if (projectPath != null) {
        await _prSyncService.triggerRefresh(projectId: projectId, projectPath: projectPath);
        return;
      }

      final fallbackDirectory = sessions.firstOrNull?.directory;
      if (fallbackDirectory == null || fallbackDirectory.isEmpty) {
        return;
      }
      await _prSyncService.triggerRefresh(projectId: projectId, projectPath: fallbackDirectory);
    } on Object catch (e, st) {
      Log.w("[GetSessionsHandler] PR refresh trigger failed for $projectId: $e\n$st");
    }
  }
}
