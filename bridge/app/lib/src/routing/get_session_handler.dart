import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `POST /session/detail` — returns a single enriched session by ID.
class GetSessionHandler({
  required final SessionRepository _sessionRepository,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SessionIdRequest, Session> {
  this
    : super(
        HttpMethod.post,
        "/session/detail",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    final catalogSession = await _sessionRepository.getCatalogSession(sessionId: sessionId);
    if (catalogSession == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }
    return await _sessionViews.enrich(session: catalogSession);
  }
}
