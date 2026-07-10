import "package:sesori_shared/sesori_shared.dart";

import "../services/session_title_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler extends BodyRequestHandler<RenameSessionRequest, Session> {
  final SessionTitleService _sessionTitleService;

  RenameSessionHandler({required SessionTitleService sessionTitleService})
    : _sessionTitleService = sessionTitleService,
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
    return _sessionTitleService.renameSession(sessionId: body.sessionId, title: body.title);
  }
}
