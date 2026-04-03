import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Merges archive status from the database with plugin session data.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  final SessionRepositoryLike _sessionRepository;
  final PrSyncService _prSyncService;

  GetSessionsHandler({
    required SessionRepositoryLike sessionRepository,
    required PrSyncService prSyncService,
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
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

    final sessions = await _sessionRepository.getSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
    );

    final response = SessionListResponse(items: sessions);

    unawaited(_triggerPrRefresh(projectId: projectId, sessions: sessions));
    return response;
  }

  Future<void> _triggerPrRefresh({
    required String projectId,
    required List<Session> sessions,
  }) async {
    final projectPath = await _sessionRepository.getProjectPath(projectId: projectId);
    if (projectPath != null && projectPath.isNotEmpty) {
      unawaited(_prSyncService.triggerRefresh(projectId: projectId, projectPath: projectPath));
      return;
    }

    final fallbackDirectory = sessions.firstOrNull?.directory;
    if (fallbackDirectory == null || fallbackDirectory.isEmpty) {
      return;
    }
    unawaited(_prSyncService.triggerRefresh(projectId: projectId, projectPath: fallbackDirectory));
  }
}
