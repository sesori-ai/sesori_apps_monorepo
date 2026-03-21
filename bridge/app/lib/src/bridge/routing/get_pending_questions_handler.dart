import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /question` — returns all pending question prompts.
///
/// Returns ALL pending questions globally — not session-scoped.
/// Each question includes its sessionID.
class GetPendingQuestionsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetPendingQuestionsHandler(this._plugin) : super(HttpMethod.get, "/question");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final pluginQuestions = await _plugin.getPendingQuestions();

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
