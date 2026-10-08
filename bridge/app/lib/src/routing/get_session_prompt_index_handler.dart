import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/prompts` — lists every prompt in a session's
/// history, oldest first.
///
/// Never answers 404: an unknown or empty session lists no prompts, so a 404
/// from this route always means a bridge that predates it.
class GetSessionPromptIndexHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionIdRequest, SessionPromptIndexResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/prompts",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionPromptIndexResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");
    return SessionPromptIndexResponse(entries: await _chatHistoryService.getPromptIndex(sessionId: sessionId));
  }
}
