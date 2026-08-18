import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/queued_prompts` — returns the prompts the bridge has
/// accepted for a session but not yet dispatched to its backend.
class GetQueuedPromptsHandler({required final SessionRepository _sessionRepository})
    extends BodyRequestHandler<SessionIdRequest, QueuedPromptResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/queued_prompts",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<QueuedPromptResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final prompts = await _sessionRepository.getQueuedPrompts(sessionId: sessionId);
    return QueuedPromptResponse(data: prompts);
  }
}
