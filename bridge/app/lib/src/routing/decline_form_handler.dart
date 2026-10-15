import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

class DeclineFormHandler({required final PendingInteractionService _service})
    extends BodyRequestHandler<DeclineFormRequest, FormReplyResult> {
  this : super(HttpMethod.post, "/form/decline", fromJson: DeclineFormRequest.fromJson);

  @override
  Future<FormReplyResult> handle(RelayRequest request, {required DeclineFormRequest body}) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.requestId, label: "request id");
    return _service.declineForm(request: body);
  }
}
