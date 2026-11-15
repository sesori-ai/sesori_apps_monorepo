import "package:sesori_shared/sesori_shared.dart";

import "../services/session_prompt_service.dart";
import "request_handler.dart";

/// Handles `POST /session/rewind` — edits a prompt that opens a turn: removes
/// it and every later message from the session's conversation, then sends the
/// edited prompt. Refusals answer `SessionBranchErrorResponse`.
class RewindSessionHandler({required final SessionPromptService _sessionPromptService})
    extends BodyRequestHandler<RewindSessionRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/rewind",
        fromJson: RewindSessionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required RewindSessionRequest body,
  }) async {
    final sessionId = requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    final messageId = requireNonEmpty(request: request, value: body.messageId, label: "message id");
    final promptId = requireNonEmpty(request: request, value: body.promptId, label: "prompt id");

    await _sessionPromptService.rewindAndSendPrompt(
      sessionId: sessionId,
      messageId: messageId,
      promptId: promptId,
      parts: body.parts,
      variant: body.variant,
      fastMode: body.fastMode,
      agent: body.agent,
      model: body.model,
    );

    return const SuccessEmptyResponse();
  }
}
