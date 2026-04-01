import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /global/health` — proxies the backend's health status.
class HealthCheckHandler extends GetRequestHandler<SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  HealthCheckHandler(this._plugin) : super("/global/health");

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    await _plugin.healthCheck();
    return const SuccessEmptyResponse();
  }
}
