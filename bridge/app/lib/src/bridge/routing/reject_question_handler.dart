import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /question/:id/reject` — rejects a pending question.
///
/// Question IDs are globally unique. No session context needed.
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
    final questionId = pathParams[_idParam];
    if (questionId == null || questionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing question id");
    }

    await _plugin.rejectQuestion(questionId);
    return RelayResponse(
      id: request.id,
      status: 200,
      headers: {},
      body: null,
    );
  }
}
