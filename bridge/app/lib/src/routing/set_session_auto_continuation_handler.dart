import "package:sesori_shared/sesori_shared.dart";

import "../services/session_continuation_service.dart";
import "request_handler.dart";

class SetSessionAutoContinuationHandler({required final SessionContinuationService _service})
    extends BodyRequestHandler<SetSessionAutoContinuationRequest, Session> {
  this : super(HttpMethod.patch, "/session/auto-continuation", fromJson: SetSessionAutoContinuationRequest.fromJson);

  @override
  Future<Session> handle(RelayRequest request, {required SetSessionAutoContinuationRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    try {
      return await _service.setEnabled(sessionId: body.sessionId, enabled: body.enabled);
    } on SessionAutoContinuationUnavailableException {
      throw buildErrorResponse(request, 501, "Quota auto continuation is unavailable for this harness");
    }
  }
}
