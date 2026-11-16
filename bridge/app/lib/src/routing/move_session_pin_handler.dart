import "package:sesori_shared/sesori_shared.dart";

import "../services/session_mutation_dispatcher.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/pin-position` — places a pinned session directly
/// below another pinned one, or at the top of the pinned group. A session or
/// anchor that is not pinned answers the route's own not-found.
class MoveSessionPinHandler({
  required final SessionMutationDispatcher _sessionMutationDispatcher,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<MoveSessionPinRequest, MoveSessionPinResponse> {
  this : super(method: HttpMethod.patch, path: "/session/pin-position", fromJson: MoveSessionPinRequest.fromJson);

  @override
  Future<MoveSessionPinResponse> handle({
    required RelayRequest request,
    required MoveSessionPinRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    if (body.afterSessionId case final afterSessionId?) {
      requireNonEmpty(request: request, value: afterSessionId, label: "after session id");
    }
    final moved = await _sessionMutationDispatcher.movePin(
      sessionId: body.sessionId,
      afterSessionId: body.afterSessionId,
    );
    return MoveSessionPinResponse(
      sessions: await _sessionViews.enrichMany(sessions: moved),
    );
  }
}
