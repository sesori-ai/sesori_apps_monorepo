import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /question/reject` — rejects a pending question.
///
/// Session context scopes modern question IDs. It remains optional for
/// backwards compatibility with older clients, where the pending owner must
/// resolve unambiguously before rejection.
class RejectQuestionHandler extends BodyRequestHandler<RejectQuestionRequest, SuccessEmptyResponse> {
  final PendingInteractionService _pendingInteractionService;

  RejectQuestionHandler({required PendingInteractionService pendingInteractionService})
    : _pendingInteractionService = pendingInteractionService,
      super(
        HttpMethod.post,
        "/question/reject",
        fromJson: RejectQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required RejectQuestionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final requestId = body.requestId;
    if (requestId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty request id");
    }

    await _pendingInteractionService.rejectQuestion(
      questionId: requestId,
      sessionId: body.sessionId,
    );

    return const SuccessEmptyResponse();
  }
}
