import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "../services/agent_page_service.dart";
import "request_handler.dart";

/// Handles `POST /session/questions` — returns the pending questions to surface
/// on a session's screen: its own plus any descendant (sub-agent) session whose
/// top-most root resolves to this session. The markers of pages agents sent
/// come after the plugin's questions.
class GetSessionQuestionsHandler({
  required final QuestionRepository _questionRepository,
  required final AgentPageService _agentPageService,
}) extends BodyRequestHandler<SessionIdRequest, PendingQuestionResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/questions",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<PendingQuestionResponse> handle({
    required RelayRequest request,
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    final questions = await _questionRepository.getPendingQuestions(sessionId: sessionId);
    final pages = await _agentPageService.pendingQuestions(sessionId: sessionId);
    return PendingQuestionResponse(data: [...questions, ...pages]);
  }
}
