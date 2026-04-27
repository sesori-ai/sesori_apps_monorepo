import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "question_mapper.dart";
import "request_handler.dart";

/// Handles `POST /project/questions` — returns all pending questions for a project.
class GetProjectQuestionsHandler extends BodyRequestHandler<ProjectIdRequest, PendingQuestionResponse> {
  final BridgePlugin _plugin;

  GetProjectQuestionsHandler(this._plugin)
    : super(
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

    final pluginQuestions = await _plugin.getProjectQuestions(projectId: projectId);
    final questions = mapPluginQuestions(pluginQuestions);

    return PendingQuestionResponse(data: questions);
  }
}
