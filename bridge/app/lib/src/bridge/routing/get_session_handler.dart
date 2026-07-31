import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `POST /session/detail` — returns a single enriched session by ID.
class GetSessionHandler extends BodyRequestHandler<SessionIdRequest, Session> {
  final SessionRepository _sessionRepository;
  final PrSyncService _prSyncService;

  GetSessionHandler({
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       super(
         HttpMethod.post,
         "/session/detail",
         fromJson: SessionIdRequest.fromJson,
       );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
    if (projectId == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    final verifiedGithubLogin = await _prSyncService.verifyGithubIdentity();
    final session = await _sessionRepository.getSessionForProject(
      projectId: projectId,
      sessionId: sessionId,
      verifiedGithubLogin: verifiedGithubLogin,
    );
    if (session == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    return session;
  }
}
