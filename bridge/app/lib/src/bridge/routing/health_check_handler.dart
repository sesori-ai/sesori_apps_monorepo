import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /global/health` — proxies the backend's health status.
class HealthCheckHandler extends RequestHandler {
  final BridgePlugin _plugin;

  HealthCheckHandler(this._plugin) : super(HttpMethod.get, "/global/health");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final body = await _plugin.healthCheck();
    return buildOkJsonResponse(request, body);
  }
}
