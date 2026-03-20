import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Catch-all handler that proxies unhandled requests to the plugin's backend.
///
/// Always placed last in the handler list. Declared with `"*"` for both method
/// and path, so [canHandle] matches any request not handled by a prior handler.
class ProxyHandler extends RequestHandler {
  final BridgePlugin _plugin;

  ProxyHandler(this._plugin) : super(HttpMethod.any, "*");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    // ignore: deprecated_member_use
    final proxy = await _plugin.proxyRequest(
      method: request.method,
      path: request.path,
      headers: request.headers,
      body: request.body,
    );
    return RelayMessage.response(
          id: request.id,
          status: proxy.status,
          headers: proxy.headers,
          body: proxy.body,
        )
        as RelayResponse;
  }
}
