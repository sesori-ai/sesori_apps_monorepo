import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler extends BodyRequestHandler<RenameSessionRequest, Session> {
  final SessionRepository _sessionRepository;

  RenameSessionHandler({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository,
      super(HttpMethod.patch, "/session/title", fromJson: RenameSessionRequest.fromJson);

  @override
  Future<Session> handle(
    RelayRequest request, {
    required RenameSessionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (body.sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    return _sessionRepository.renameSession(sessionId: body.sessionId, title: body.title);
  }
}
