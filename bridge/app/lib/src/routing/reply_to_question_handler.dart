import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /question/reply` — replies to a pending question.
class ReplyToQuestionHandler({required final PendingInteractionService _pendingInteractionService})
    extends BodyRequestHandler<ReplyToQuestionRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/question/reply",
        fromJson: ReplyToQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required ReplyToQuestionRequest body,
  }) async {
    final requestId = body.requestId;
    requireNonEmpty(request, requestId, "request id");
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");

    await _pendingInteractionService.replyToQuestion(
      questionId: requestId,
      sessionId: sessionId,
      answers: body.answers,
    );

    return const SuccessEmptyResponse();
  }
}
