import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /question/reject` — rejects a pending question.
///
/// Session context scopes question IDs to their owning session.
class RejectQuestionHandler({required final PendingInteractionService _pendingInteractionService})
    extends BodyRequestHandler<RejectQuestionRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/question/reject",
        fromJson: RejectQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required RejectQuestionRequest body,
  }) async {
    final requestId = body.requestId;
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: requestId, label: "request id");
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    await _pendingInteractionService.rejectQuestion(
      questionId: requestId,
      sessionId: sessionId,
    );

    return const SuccessEmptyResponse();
  }
}
