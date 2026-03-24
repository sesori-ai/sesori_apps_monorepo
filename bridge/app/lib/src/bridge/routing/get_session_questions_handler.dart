import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "question_mapper.dart";
import "request_handler.dart";

const _idParam = "id";

/// Handles `GET /session/:id/questions` — returns all pending question prompts for a session.
///
/// Returns ALL pending questions for a session.
class GetSessionQuestionsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetSessionQuestionsHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/questions");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final pluginQuestions = await _plugin.getPendingQuestions(sessionId: sessionId);
    final questions = mapPluginQuestions(pluginQuestions);

    return buildOkJsonResponse(request, jsonEncode(questions.map((q) => q.toJson()).toList()));
  }
}
