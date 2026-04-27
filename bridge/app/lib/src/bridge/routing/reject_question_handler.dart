import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /question/reject` — rejects a pending question.
///
/// Question IDs are globally unique. No session context needed.
class RejectQuestionHandler extends BodyRequestHandler<RejectQuestionRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  RejectQuestionHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/question/reject",
        fromJson: RejectQuestionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required RejectQuestionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final requestId = body.requestId;
    if (requestId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty request id");
    }

    await _plugin.rejectQuestion(requestId);

    return const SuccessEmptyResponse();
  }
}
