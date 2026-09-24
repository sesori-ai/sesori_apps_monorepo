import "package:sesori_shared/sesori_shared.dart";

import "../services/session_creation_service.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler({
  required final SessionCreationService _sessionCreationService,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<CreateSessionRequest, Session> {
  this
    : super(
        HttpMethod.post,
        "/session/create",
        fromJson: CreateSessionRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required CreateSessionRequest body,
  }) async {
    return await _sessionViews.enrich(session: await _sessionCreationService.createSession(request: body));
  }
}
