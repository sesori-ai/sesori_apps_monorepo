import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `DELETE /session/:id` — deletes a session.
class DeleteSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  DeleteSessionHandler(this._plugin) : super(HttpMethod.delete, "/session/:$_idParam");

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

    try {
      await _plugin.deleteSession(sessionId);
    } on PluginApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    return RelayMessage.response(
          id: request.id,
          status: 200,
          headers: {},
          body: null,
        )
        as RelayResponse;
  }
}
