import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /session/:id/abort` — aborts in-progress session execution.
class AbortSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  AbortSessionHandler(this._plugin) : super(HttpMethod.post, "/session/:$_idParam/abort");

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

    await _plugin.abortSession(sessionId: sessionId);
    return RelayResponse(
      id: request.id,
      status: 200,
      headers: {},
      body: null,
    );
  }
}
