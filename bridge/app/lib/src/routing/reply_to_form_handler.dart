import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

class ReplyToFormHandler({required final PendingInteractionService _service})
    extends BodyRequestHandler<ReplyToFormRequest, FormReplyResult> {
  this : super(HttpMethod.post, "/form/reply", fromJson: ReplyToFormRequest.fromJson);

  @override
  Future<FormReplyResult> handle(RelayRequest request, {required ReplyToFormRequest body}) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.requestId, label: "request id");
    return _service.replyToForm(request: body);
  }
}
