import "package:sesori_shared/sesori_shared.dart";

import "../services/session_abort_service.dart";
import "request_handler.dart";

/// Handles `POST /session/:id/abort` — aborts in-progress session execution.
class AbortSessionHandler({
  required final SessionAbortService _sessionAbortService,
}) extends BodyRequestHandler<SessionIdRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/abort",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    await _sessionAbortService.abortSession(sessionId: body.sessionId);
    return const SuccessEmptyResponse();
  }
}
