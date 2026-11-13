import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/history_window.dart";
import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/messages/through` — returns every message from
/// `throughSeq` up to `before` in one response, through the same read path as
/// a page.
class GetSessionMessagesThroughHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionMessagesThroughRequest, MessageWithPartsResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/messages/through",
        fromJson: SessionMessagesThroughRequest.fromJson,
      );

  @override
  Future<MessageWithPartsResponse> handle({
    required RelayRequest request,
    required SessionMessagesThroughRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");
    if (body.throughSeq >= body.before) {
      throw buildErrorResponse(request: request, status: 400, message: "throughSeq must be lower than before");
    }

    final page = await _chatHistoryService.getSessionMessages(
      sessionId: sessionId,
      window: HistoryWindowThrough(throughSeq: body.throughSeq, before: body.before),
      attachmentDelivery: body.attachmentDelivery,
      toolOutputDelivery: body.toolOutputDelivery,
      storedOnly: body.storedOnly,
      // A load-through is the reader scrolling back, which waits as before.
      backgroundRefresh: false,
    );
    return MessageWithPartsResponse(
      messages: page.messages,
      nextCursor: page.nextCursor,
      replayedPromptDefaults: page.replayedPromptDefaults,
      awaitingHarnessSync: page.awaitingHarnessSync,
      userMessagesBefore: page.userMessagesBefore,
      cannotContinueMessage: page.cannotContinueMessage,
    );
  }
}
