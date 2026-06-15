import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "request_handler.dart";

/// Handles `POST /question/reject` — rejects a pending question.
///
/// Question IDs are globally unique. Session context is optional for backwards
/// compatibility with older mobile clients.
class RejectQuestionHandler extends BodyRequestHandler<RejectQuestionRequest, SuccessEmptyResponse> {
  final QuestionRepository _questionRepository;

  RejectQuestionHandler({required QuestionRepository questionRepository})
    : _questionRepository = questionRepository,
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

    await _questionRepository.rejectQuestion(
      questionId: requestId,
      sessionId: body.sessionId,
    );

    return const SuccessEmptyResponse();
  }
}
