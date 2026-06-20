import "package:sesori_shared/sesori_shared.dart";

import "../repositories/question_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/questions` — returns all pending questions for a project.
class GetProjectQuestionsHandler extends BodyRequestHandler<ProjectIdRequest, PendingQuestionResponse> {
  final QuestionRepository _questionRepository;

  GetProjectQuestionsHandler({required QuestionRepository questionRepository})
    : _questionRepository = questionRepository,
      super(
        HttpMethod.post,
        "/project/questions",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<PendingQuestionResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    if (projectId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty project id");
    }

    final questions = await _questionRepository.getProjectQuestions(projectId: projectId);
    return PendingQuestionResponse(data: questions);
  }
}
