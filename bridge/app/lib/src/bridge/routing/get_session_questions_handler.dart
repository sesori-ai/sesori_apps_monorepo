import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/questions` — returns the pending questions to surface
/// on a session's screen: its own plus any descendant (sub-agent) session whose
/// top-most root resolves to this session.
class GetSessionQuestionsHandler extends BodyRequestHandler<SessionIdRequest, PendingQuestionResponse> {
  final QuestionRepository _questionRepository;

  GetSessionQuestionsHandler({required QuestionRepository questionRepository})
    : _questionRepository = questionRepository,
      super(
        HttpMethod.post,
        "/session/questions",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<PendingQuestionResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final questions = await _questionRepository.getPendingQuestions(sessionId: sessionId);
    return PendingQuestionResponse(data: questions);
  }
}
