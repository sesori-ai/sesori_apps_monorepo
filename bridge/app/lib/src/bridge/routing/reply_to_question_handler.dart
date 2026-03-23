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
      Log.e("[question-reply] missing question id in path params");
      return buildErrorResponse(request, 400, "missing question id");
    }

    Log.d("[question-reply] received reply for questionId=$questionId");

    final bodyRaw = request.body;
    if (bodyRaw == null) {
      Log.e("[question-reply] missing body for questionId=$questionId");
      return buildErrorResponse(request, 400, "missing answers in JSON body");
    }

    Log.v("[question-reply] raw body: $bodyRaw");

    final ReplyToQuestionRequest replyRequest;
    try {
      final decoded = jsonDecode(bodyRaw);
      replyRequest = ReplyToQuestionRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException catch (e) {
      Log.e("[question-reply] body parse failed (FormatException): $e");
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object catch (e) {
      Log.e("[question-reply] body parse failed: $e");
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final answers = replyRequest.answers.map((answer) => answer.values).toList();
    Log.v("[question-reply] parsed ${answers.length} answer(s) for questionId=$questionId: $answers");

    try {
      await _plugin.replyToQuestion(questionId, answers: answers);
      Log.v("[question-reply] plugin.replyToQuestion completed OK for questionId=$questionId");
    } catch (e) {
      Log.e("[question-reply] plugin.replyToQuestion FAILED for questionId=$questionId: $e");
      rethrow;
    }

    return RelayResponse(
      id: request.id,
      status: 200,
      headers: {},
      body: null,
    );
  }
}
