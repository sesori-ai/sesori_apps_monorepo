import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /question/:id/reject` — rejects a pending question.
class RejectQuestionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  RejectQuestionHandler(this._plugin) : super(HttpMethod.post, "/question/:$_idParam/reject");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final questionId = pathParams[_idParam]!;
    await _plugin.rejectQuestion(questionId);
    return RelayMessage.response(
          id: request.id,
          status: 200,
          headers: {},
          body: null,
        )
        as RelayResponse;
  }
}
