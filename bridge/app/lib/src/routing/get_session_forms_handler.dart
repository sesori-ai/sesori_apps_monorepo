import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

class GetSessionFormsHandler({required final PendingInteractionService _service})
    extends BodyRequestHandler<SessionIdRequest, PendingFormsResponse> {
  this : super(HttpMethod.post, "/session/forms", fromJson: SessionIdRequest.fromJson);

  @override
  Future<PendingFormsResponse> handle(RelayRequest request, {required SessionIdRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return PendingFormsResponse(data: await _service.getPendingForms(sessionId: body.sessionId));
  }
}
