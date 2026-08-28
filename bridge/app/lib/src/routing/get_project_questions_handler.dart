import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/questions` — returns all pending questions for a project.
class GetProjectQuestionsHandler({required final QuestionRepository _questionRepository})
    extends BodyRequestHandler<ProjectIdRequest, PendingQuestionResponse> {
  this
    : super(
        HttpMethod.post,
        "/project/questions",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<PendingQuestionResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
  }) async {
    final projectId = body.projectId;
    requireNonEmpty(request: request, value: projectId, label: "project id");

    final questions = await _questionRepository.getProjectQuestions(projectId: projectId);
    return PendingQuestionResponse(data: questions);
  }
}
