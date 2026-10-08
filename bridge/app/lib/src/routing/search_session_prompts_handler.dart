import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/prompts/search` — finds a query in the whole text of
/// every prompt in a session's history, oldest first.
///
/// Never answers 404: an unknown session, an empty one or a blank query
/// matches nothing, so a 404 from this route always means a bridge that
/// predates it.
class SearchSessionPromptsHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionPromptSearchRequest, SessionPromptSearchResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/prompts/search",
        fromJson: SessionPromptSearchRequest.fromJson,
      );

  @override
  Future<SessionPromptSearchResponse> handle(
    RelayRequest request, {
    required SessionPromptSearchRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");
    return SessionPromptSearchResponse(
      matches: await _chatHistoryService.searchPrompts(sessionId: sessionId, query: body.query),
    );
  }
}
