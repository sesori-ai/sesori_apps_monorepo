import "package:sesori_shared/sesori_shared.dart";

import "../services/session_prompt_service.dart";
import "request_handler.dart";

/// Handles `POST /session/prompt_async` — sends a prompt to a session.
class SendPromptHandler extends BodyRequestHandler<SendPromptRequest, SuccessEmptyResponse> {
  final SessionPromptService _sessionPromptService;

  SendPromptHandler({required SessionPromptService sessionPromptService})
    : _sessionPromptService = sessionPromptService,
      super(
        HttpMethod.post,
        "/session/prompt_async",
        fromJson: SendPromptRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SendPromptRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    await _sessionPromptService.sendPrompt(
      sessionId: sessionId,
      parts: body.parts,
      variant: body.variant,
      agent: body.agent,
      model: body.model,
      command: body.command,
    );

    return const SuccessEmptyResponse();
  }
}
