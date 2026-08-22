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
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final requestId = body.requestId;
    if (requestId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty request id");
    }
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    await _pendingInteractionService.replyToQuestion(
      questionId: requestId,
      sessionId: sessionId,
      answers: body.answers,
    );

    return const SuccessEmptyResponse();
  }
}
