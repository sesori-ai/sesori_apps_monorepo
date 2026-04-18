import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/session_persistence_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Merges archive status from the database with plugin session data.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final SessionRepository _sessionRepository;
  final PrSyncService _prSyncService;
  final SessionPersistenceService _sessionPersistenceService;

  GetSessionsHandler({
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    required SessionPersistenceService sessionPersistenceService,
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       _sessionPersistenceService = sessionPersistenceService,
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

    await _sessionPersistenceService.ensureProject(projectId: projectId);

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

    final response = SessionListResponse(items: sessions);

    unawaited(_triggerPrRefresh(projectId: projectId, sessions: sessions));
    return response;
  }

  Future<void> _triggerPrRefresh({
    required String projectId,
    required List<Session> sessions,
  }) async {
    try {
      final projectPath = await _sessionRepository.getProjectPath(projectId: projectId);
      if (projectPath != null) {
        unawaited(_prSyncService.triggerRefresh(projectId: projectId, projectPath: projectPath));
        return;
      }

      final fallbackDirectory = sessions.firstOrNull?.directory;
      if (fallbackDirectory == null || fallbackDirectory.isEmpty) {
        return;
      }
      unawaited(_prSyncService.triggerRefresh(projectId: projectId, projectPath: fallbackDirectory));
    } on Object catch (e, st) {
      Log.w("[GetSessionsHandler] PR refresh trigger failed for $projectId: $e\n$st");
    }
  }
}
