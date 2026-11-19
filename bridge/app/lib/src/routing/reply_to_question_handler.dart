import "package:sesori_shared/sesori_shared.dart";

import "../services/agent_page_service.dart";
import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /question/reply` — replies to a pending question. A page an
/// agent sent can only be cancelled through the question routes, so a reply
/// to one dismisses it.
class ReplyToQuestionHandler({
  required final AgentPageService _agentPageService,
  required final PendingInteractionService _pendingInteractionService,
}) extends BodyRequestHandler<ReplyToQuestionRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/question/reply",
        fromJson: ReplyToQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required ReplyToQuestionRequest body,
  }) async {
    final requestId = body.requestId;
    requireNonEmpty(request: request, value: requestId, label: "request id");
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    switch (await _agentPageService.dismiss(requestId: requestId, sessionId: sessionId)) {
      case NotAgentPage():
        await _pendingInteractionService.replyToQuestion(
          questionId: requestId,
          sessionId: sessionId,
          answers: body.answers,
        );
      case AgentPageReplyDismissed():
        break;
      case AgentPageAlreadySettled():
        throw buildErrorResponse(request: request, status: 404, message: "This page is no longer pending.");
    }

    return const SuccessEmptyResponse();
  }
}
