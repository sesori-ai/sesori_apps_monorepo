import "package:sesori_shared/sesori_shared.dart";

import "../repositories/external_action_repository.dart";
import "request_handler.dart";

class GetSessionExternalActionsHandler({required final ExternalActionRepository _repository})
    extends BodyRequestHandler<SessionIdRequest, PendingExternalActionsResponse> {
  this : super(HttpMethod.post, "/session/external-actions", fromJson: SessionIdRequest.fromJson);

  @override
  Future<PendingExternalActionsResponse> handle(RelayRequest request, {required SessionIdRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return PendingExternalActionsResponse(data: await _repository.getPending(sessionId: body.sessionId));
  }
}
