import "package:sesori_shared/sesori_shared.dart";

import "../services/session_prompt_service.dart";
import "request_handler.dart";

/// Handles `POST /session/prompt_async` — sends a prompt to a session.
class SendPromptHandler({required final SessionPromptService _sessionPromptService})
    extends BodyRequestHandler<SendPromptRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/prompt_async",
        fromJson: SendPromptRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SendPromptRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");

    await _sessionPromptService.sendPrompt(
      sessionId: sessionId,
      promptId: body.promptId,
      parts: body.parts,
      variant: body.variant,
      agent: body.agent,
      model: body.model,
      command: body.command,
    );

    return const SuccessEmptyResponse();
  }
}
