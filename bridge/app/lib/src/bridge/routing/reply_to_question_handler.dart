import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /question/:id/reply` — replies to a pending question.
class ReplyToQuestionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  ReplyToQuestionHandler(this._plugin) : super(HttpMethod.post, "/question/:$_idParam/reply");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final questionId = pathParams[_idParam]!;

    final bodyRaw = request.body;
    if (bodyRaw == null) {
      return buildErrorResponse(request, 400, "missing answers in JSON body");
    }

    final List<List<String>> answers;
    try {
      final body = jsonDecode(bodyRaw) as Map<String, dynamic>;
      final answersRaw = body["answers"];
      if (answersRaw is! List<dynamic>) {
        return buildErrorResponse(request, 400, "missing answers in JSON body");
      }

      answers = answersRaw
          .map(
            (entry) => (entry as List<dynamic>).map((value) => value as String).toList(),
          )
          .toList();
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    await _plugin.replyToQuestion(questionId, answers: answers);
    return RelayMessage.response(
          id: request.id,
          status: 200,
          headers: {},
          body: null,
        )
        as RelayResponse;
  }
}
