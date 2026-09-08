import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_abort_result.dart";
import "../services/session_abort_service.dart";
import "request_handler.dart";

/// Handles `POST /session/abort` — stops in-progress session execution.
class AbortSessionHandler({
  required final SessionAbortService _sessionAbortService,
}) extends BodyRequestHandler<AbortSessionRequest, SessionAbortResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/abort",
        fromJson: AbortSessionRequest.fromJson,
      );

  @override
  Future<SessionAbortResponse> handle(
    RelayRequest request, {
    required AbortSessionRequest body,
  }) async {
    final result = await _sessionAbortService.abortSession(
      sessionId: body.sessionId,
      subAgents: body.subAgents,
      useAtomicStop: body.useAtomicStop,
    );
    return switch (result) {
      SessionAborted(:final subAgentsHandled) => SessionAbortResponse(subAgentsHandled: subAgentsHandled),
      // The app parses the 409 body as SessionAbortRejection JSON.
      SessionAbortRejected(:final rejection) => throw buildJsonErrorResponse(
        request: request,
        status: 409,
        body: rejection.toJson(),
      ),
    };
  }
}
