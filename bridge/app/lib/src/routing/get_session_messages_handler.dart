import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/messages` — returns a page of a session's messages,
/// or the whole transcript when the request carries no limit.
class GetSessionMessagesHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionMessagesRequest, MessageWithPartsResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/messages",
        fromJson: SessionMessagesRequest.fromJson,
      );

  @override
  Future<MessageWithPartsResponse> handle(
    RelayRequest request, {
    required SessionMessagesRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");
    // A non-positive limit has no honest answer: it is neither "the whole
    // transcript" (null) nor a page anyone can page onward from, so refuse it
    // rather than returning an empty page that never terminates.
    if (body.limit case final limit? when limit <= 0) {
      throw buildErrorResponse(request, 400, "limit must be greater than zero");
    }

    final page = await _chatHistoryService.getSessionMessages(
      sessionId: sessionId,
      limit: body.limit,
      before: body.before,
      attachmentDelivery: body.attachmentDelivery,
    );
    return MessageWithPartsResponse(messages: page.messages, nextCursor: page.nextCursor);
  }
}
