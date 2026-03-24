import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "question_mapper.dart";
import "request_handler.dart";

/// Handles `GET /questions` — returns all pending questions for a project.
///
/// Requires `x-project-id` header to scope questions to a project's sessions.
class GetProjectQuestionsHandler extends RequestHandler {
  static const _projectIdHeader = "x-project-id";
  final BridgePlugin _plugin;

  GetProjectQuestionsHandler(this._plugin) : super(HttpMethod.get, "/questions");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final projectId = findHeader(request.headers, _projectIdHeader);
    if (projectId == null || projectId.isEmpty) {
      return buildErrorResponse(
        request,
        400,
        "missing $_projectIdHeader header",
      );
    }

    final pluginQuestions = await _plugin.getProjectQuestions(projectId: projectId);
    final questions = mapPluginQuestions(pluginQuestions);

    return buildOkJsonResponse(request, jsonEncode(questions.map((q) => q.toJson()).toList()));
  }
}
