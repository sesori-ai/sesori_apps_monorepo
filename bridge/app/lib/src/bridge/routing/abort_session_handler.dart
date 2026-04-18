import "package:sesori_shared/sesori_shared.dart";

import "../services/session_abort_service.dart";
import "request_handler.dart";

/// Handles `POST /session/:id/abort` — aborts in-progress session execution.
class AbortSessionHandler extends BodyRequestHandler<SessionIdRequest, SuccessEmptyResponse> {
  final SessionAbortService _sessionAbortService;

  AbortSessionHandler({
    required SessionAbortService sessionAbortService,
  }) : _sessionAbortService = sessionAbortService,
       super(
         HttpMethod.post,
         "/session/abort",
         fromJson: SessionIdRequest.fromJson,
       );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    await _sessionAbortService.abortSession(sessionId: body.sessionId);
    return const SuccessEmptyResponse();
  }
}
