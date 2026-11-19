import "package:sesori_shared/sesori_shared.dart";

import "../services/agent_page_service.dart";
import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /question/reject` — rejects a pending question, or dismisses
/// a page an agent sent.
///
/// Session context scopes question IDs to their owning session.
class RejectQuestionHandler({
  required final AgentPageService _agentPageService,
  required final PendingInteractionService _pendingInteractionService,
}) extends BodyRequestHandler<RejectQuestionRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/question/reject",
        fromJson: RejectQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required RejectQuestionRequest body,
  }) async {
    final requestId = body.requestId;
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: requestId, label: "request id");
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    switch (await _agentPageService.dismiss(requestId: requestId, sessionId: sessionId)) {
      case NotAgentPage():
        await _pendingInteractionService.rejectQuestion(
          questionId: requestId,
          sessionId: sessionId,
        );
      case AgentPageReplyDismissed():
        break;
      case AgentPageAlreadySettled():
        throw buildErrorResponse(request: request, status: 404, message: "This page is no longer pending.");
    }

    return const SuccessEmptyResponse();
  }
}
