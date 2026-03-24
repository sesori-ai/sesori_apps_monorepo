import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `GET /session/:id/questions` — returns all pending question prompts for a session.
///
/// Returns ALL pending questions for a session
class GetPendingQuestionsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetPendingQuestionsHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/questions");

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

    Log.d("pluginQuestions: $pluginQuestions");

    final questions = pluginQuestions
        .map(
          (q) => PendingQuestion(
            id: q.id,
            sessionID: q.sessionID,
            questions: q.questions
                .map(
                  (qi) => QuestionInfo(
                    question: qi.question,
                    header: qi.header,
                    options: qi.options
                        .map(
                          (o) => QuestionOption(
                            label: o.label,
                            description: o.description,
                          ),
                        )
                        .toList(),
                    multiple: qi.multiple,
                    custom: qi.custom,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    return buildOkJsonResponse(request, jsonEncode(questions.map((q) => q.toJson()).toList()));
  }
}
