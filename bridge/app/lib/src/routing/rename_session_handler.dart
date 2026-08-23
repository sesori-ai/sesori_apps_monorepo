import "package:sesori_shared/sesori_shared.dart";

import "../services/session_mutation_dispatcher.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler({required final SessionMutationDispatcher _sessionMutationDispatcher})
    extends BodyRequestHandler<RenameSessionRequest, Session> {
  this : super(HttpMethod.patch, "/session/title", fromJson: RenameSessionRequest.fromJson);

  @override
  Future<Session> handle(
    RelayRequest request, {
    required RenameSessionRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return await _sessionMutationDispatcher.renameSession(sessionId: body.sessionId, title: body.title);
  }
}
