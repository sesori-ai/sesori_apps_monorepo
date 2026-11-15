import "package:sesori_shared/sesori_shared.dart";

import "../services/session_mutation_dispatcher.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/pinned` — pins or unpins a root session. A missing,
/// child or archived session to pin answers the route's own not-found.
class SetSessionPinnedHandler({
  required final SessionMutationDispatcher _sessionMutationDispatcher,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SetSessionPinnedRequest, Session> {
  this : super(method: HttpMethod.patch, path: "/session/pinned", fromJson: SetSessionPinnedRequest.fromJson);

  @override
  Future<Session> handle({
    required RelayRequest request,
    required SetSessionPinnedRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return await _sessionViews.enrich(
      session: await _sessionMutationDispatcher.setPinned(sessionId: body.sessionId, pinned: body.pinned),
    );
  }
}
