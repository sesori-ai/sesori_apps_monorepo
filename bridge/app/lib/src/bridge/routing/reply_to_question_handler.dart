import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /question/:id/reply` — replies to a pending question.
///
/// Question IDs are globally unique in the backend.
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
    final questionId = pathParams[_idParam];
    if (questionId == null || questionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing question id");
    }

    final bodyRaw = request.body;
    if (bodyRaw == null) {
      return buildErrorResponse(request, 400, "missing answers in JSON body");
    }

    final ReplyToQuestionRequest replyRequest;
    try {
      replyRequest = ReplyToQuestionRequest.fromJson(
        jsonDecode(bodyRaw) as Map<String, dynamic>,
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    await _plugin.replyToQuestion(questionId, answers: replyRequest.answers);
    return RelayMessage.response(
          id: request.id,
          status: 200,
          headers: {},
          body: null,
        )
        as RelayResponse;
  }
}
