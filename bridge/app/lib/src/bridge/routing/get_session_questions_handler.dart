import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "question_mapper.dart";
import "request_handler.dart";

/// Handles `POST /session/questions` — returns all pending question prompts for a session.
///
/// Returns ALL pending questions for a session.
class GetSessionQuestionsHandler extends BodyRequestHandler<SessionIdRequest, PendingQuestionResponse> {
  final BridgePlugin _plugin;

  GetSessionQuestionsHandler(this._plugin)
    : super(
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

    final pluginQuestions = await _plugin.getPendingQuestions(sessionId: sessionId);
    final questions = mapPluginQuestions(pluginQuestions);

    return PendingQuestionResponse(data: questions);
  }
}
