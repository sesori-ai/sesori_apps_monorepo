import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

class GetSessionExternalActionsHandler({required final PendingInteractionService _service})
    extends BodyRequestHandler<SessionIdRequest, PendingExternalActionsResponse> {
  this : super(method: HttpMethod.post, path: "/session/external-actions", fromJson: SessionIdRequest.fromJson);

  @override
  Future<PendingExternalActionsResponse> handle({required RelayRequest request, required SessionIdRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return PendingExternalActionsResponse(data: await _service.getPendingExternalActions(sessionId: body.sessionId));
  }
}
