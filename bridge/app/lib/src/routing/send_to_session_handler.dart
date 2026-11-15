import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../services/session_send_rejected_exception.dart";
import "../services/session_send_service.dart";
import "request_handler.dart";

/// Handles `POST /session/send-to-session`: sends the source session into the
/// target and answers once the target has accepted the handoff prompt.
///
/// The request stays open while the source writes its summary. A send that
/// did not happen answers 409 with a [SendToSessionErrorResponse]; a missing
/// session answers 404.
class SendToSessionHandler({required final SessionSendService _sessionSendService})
    extends BodyRequestHandler<SendToSessionRequest, SuccessEmptyResponse> {
  this : super(method: HttpMethod.post, path: "/session/send-to-session", fromJson: SendToSessionRequest.fromJson);

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required SendToSessionRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sourceSessionId, label: "source session id");
    requireNonEmpty(request: request, value: body.targetSessionId, label: "target session id");
    try {
      await _sessionSendService.send(sourceSessionId: body.sourceSessionId, targetSessionId: body.targetSessionId);
    } on SessionSendRejectedException catch (error) {
      final description = "Did not send session ${body.sourceSessionId} to ${body.targetSessionId}: ${error.code.name}";
      if (error.cause case final cause?) {
        Log.w(description, cause, error.causeStackTrace);
      } else {
        Log.i(description);
      }
      throw buildJsonErrorResponse(
        request: request,
        status: 409,
        body: SendToSessionErrorResponse(code: error.code, message: error.userFacingReason).toJson(),
      );
    }
    return const SuccessEmptyResponse();
  }
}
