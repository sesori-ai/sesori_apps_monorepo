import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/questions` — returns the pending questions to surface
/// on a session's screen: its own plus any descendant (sub-agent) session whose
/// top-most root resolves to this session.
class GetSessionQuestionsHandler({required final QuestionRepository _questionRepository})
    extends BodyRequestHandler<SessionIdRequest, PendingQuestionResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/questions",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<PendingQuestionResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");

    final questions = await _questionRepository.getPendingQuestions(sessionId: sessionId);
    return PendingQuestionResponse(data: questions);
  }
}
