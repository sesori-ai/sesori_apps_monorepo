import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/messages` — returns a page of a session's messages,
/// or the whole transcript when the request carries no limit.
class GetSessionMessagesHandler extends BodyRequestHandler<SessionMessagesRequest, MessageWithPartsResponse> {
  final ChatHistoryService _chatHistoryService;

  GetSessionMessagesHandler({required ChatHistoryService chatHistoryService})
    : _chatHistoryService = chatHistoryService,
      super(
        HttpMethod.post,
        "/session/messages",
        fromJson: SessionMessagesRequest.fromJson,
      );

  @override
  Future<MessageWithPartsResponse> handle(
    RelayRequest request, {
    required SessionMessagesRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final page = await _chatHistoryService.getSessionMessages(
      sessionId: sessionId,
      limit: body.limit,
      before: body.before,
    );
    return MessageWithPartsResponse(messages: page.messages, nextCursor: page.nextCursor);
  }
}
