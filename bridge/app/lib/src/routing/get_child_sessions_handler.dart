import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/:id/children` — returns direct child sessions.
class GetChildSessionsHandler({required final SessionRepository _sessionRepository})
    extends BodyRequestHandler<SessionIdRequest, SessionListResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/children",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionListResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    final sessions = await _sessionRepository.getChildSessions(sessionId: sessionId);
    return SessionListResponse(items: sessions);
  }
}
