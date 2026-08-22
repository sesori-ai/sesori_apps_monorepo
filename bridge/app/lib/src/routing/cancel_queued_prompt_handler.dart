import "package:sesori_shared/sesori_shared.dart";

import "../services/session_prompt_service.dart";
import "request_handler.dart";

/// Handles `POST /session/prompt/cancel` — removes a bridge-queued prompt
/// before it dispatches to the backend.
class CancelQueuedPromptHandler({required final SessionPromptService _sessionPromptService})
    extends BodyRequestHandler<CancelQueuedPromptRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/prompt/cancel",
        fromJson: CancelQueuedPromptRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required CancelQueuedPromptRequest body,
  }) async {
    requireNonEmpty(request, body.sessionId, "session or prompt id");
    requireNonEmpty(request, body.promptId, "session or prompt id");

    final removed = await _sessionPromptService.cancelQueuedPrompt(
      sessionId: body.sessionId,
      promptId: body.promptId,
    );
    // Clients treat this as benign: the entry already dispatched (became a
    // turn) or was removed by another client.
    if (!removed) {
      throw buildErrorResponse(request, 404, "queued prompt not found");
    }
    return const SuccessEmptyResponse();
  }
}
