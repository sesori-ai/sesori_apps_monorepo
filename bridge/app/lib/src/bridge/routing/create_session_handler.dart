import "package:sesori_shared/sesori_shared.dart";

import "../services/session_creation_service.dart";
import "request_handler.dart";

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler({
  required final SessionCreationService _sessionCreationService,
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
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return await _sessionCreationService.createSession(request: body);
  }
}
