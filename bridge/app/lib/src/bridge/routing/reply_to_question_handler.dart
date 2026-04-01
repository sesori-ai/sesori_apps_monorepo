import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /question/reply` — replies to a pending question.
///
/// Question IDs are globally unique in the backend.
class ReplyToQuestionHandler extends BodyRequestHandler<ReplyToQuestionRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  ReplyToQuestionHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/question/reply",
        fromJson: ReplyToQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required ReplyToQuestionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final requestId = body.requestId;
    if (requestId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty request id");
    }
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final answers = body.answers.map((answer) => answer.values).toList();

    await _plugin.replyToQuestion(
      questionId: requestId,
      sessionId: sessionId,
      answers: answers,
    );

    return const SuccessEmptyResponse();
  }
}
