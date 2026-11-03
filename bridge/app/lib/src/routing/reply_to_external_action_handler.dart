import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

class ReplyToExternalActionHandler({required final PendingInteractionService _service})
    extends BodyRequestHandler<ReplyToExternalActionRequest, ExternalActionReplyResult> {
  this
    : super(method: HttpMethod.post, path: "/external-action/reply", fromJson: ReplyToExternalActionRequest.fromJson);

  @override
  Future<ExternalActionReplyResult> handle({
    required RelayRequest request,
    required ReplyToExternalActionRequest body,
  }) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.requestId, label: "request id");
    return _service.replyToExternalAction(request: body);
  }
}
