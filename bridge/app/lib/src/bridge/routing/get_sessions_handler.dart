import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Reads the durable catalog and applies bridge-owned enrichment.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final SessionRepository _sessionRepository;
  final PrSyncService _prSyncService;
  final Duration _prRefreshTimeout;

  GetSessionsHandler({
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    Duration prRefreshTimeout = const Duration(seconds: 5),
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
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

    final sessionsWithoutPullRequestData = await _sessionRepository.getSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
      verifiedGithubLogin: null,
    );

    var sessions = sessionsWithoutPullRequestData;
    final verifiedGithubLogin = await _prSyncService.verifyGithubIdentity();
    try {
      sessions = await _sessionRepository.enrichSessions(
        sessions: sessions,
        verifiedGithubLogin: verifiedGithubLogin,
      );
    } on Object catch (e, st) {
      Log.w("GetSessionsHandler: post-publication enrichment failed", e, st);
    }

    final prRefreshFuture = _triggerPrRefresh(projectId: projectId, sessions: sessions);

    if (body.waitForPrData) {
      try {
        final refreshOutcome = await prRefreshFuture.timeout(_prRefreshTimeout);
        if (refreshOutcome == PrRefreshOutcome.failed) {
          return SessionListResponse(items: sessionsWithoutPullRequestData);
        }
        // Refresh succeeded within timeout — enrich the already-fetched sessions
        // with updated PR/CI metadata from the database (no extra plugin round-trip).
        final refreshedGithubLogin = await _prSyncService.verifyGithubIdentity();
        final enrichedSessions = await _sessionRepository.enrichSessions(
          sessions: sessions,
          verifiedGithubLogin: refreshedGithubLogin,
        );
        return SessionListResponse(items: enrichedSessions);
      } catch (err, st) {
        Log.w(
          "PR refresh or final identity-gated mapping failed after waiting up to "
          "${_prRefreshTimeout.inSeconds}s — "
          "returning sessions without cached PR data; SSE will deliver updates when ready",
          err,
          st,
        );
        return SessionListResponse(items: sessionsWithoutPullRequestData);
      }
    } else {
      // COMPATIBILITY 2026-08-01 (v1.6.1): Released clients rely on the
      // non-waiting request to trigger background PR refresh. Remove this path
      // only after those client versions are no longer supported.
      unawaited(prRefreshFuture);
    }

    return SessionListResponse(items: sessions);
  }

  Future<PrRefreshOutcome> _triggerPrRefresh({
    required String projectId,
    required List<Session> sessions,
  }) async {
    try {
      final projectPath = await _sessionRepository.getProjectPath(projectId: projectId);
      if (projectPath != null) {
        return _prSyncService.triggerRefresh(projectId: projectId, projectPath: projectPath);
      }

      final fallbackDirectory = sessions.firstOrNull?.directory;
      if (fallbackDirectory == null || fallbackDirectory.isEmpty) {
        return PrRefreshOutcome.completed;
      }
      return _prSyncService.triggerRefresh(projectId: projectId, projectPath: fallbackDirectory);
    } on Object catch (e, st) {
      Log.w("[GetSessionsHandler] PR refresh trigger failed", e, st);
      return PrRefreshOutcome.failed;
    }
  }
}
