import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "get_projects_handler.dart";
import "get_providers_handler.dart";
import "get_session_messages_handler.dart";
import "get_sessions_handler.dart";
import "health_check_handler.dart";
import "proxy_handler.dart";
import "request_handler.dart";

/// Routes incoming [RelayRequest]s to the first matching [RequestHandler].
///
/// Handlers are checked in registration order. The last handler ([ProxyHandler])
/// is a catch-all that forwards anything unmatched to the plugin's backend.
///
/// Error handling is centralised here: any exception thrown by a handler is
/// converted to a `502` response so callers never have to deal with routing
/// failures.
class RequestRouter {
  final List<RequestHandler> _handlers;

  RequestRouter(BridgePlugin plugin)
    : _handlers = [
        HealthCheckHandler(plugin),
        GetProjectsHandler(plugin),
        GetSessionsHandler(plugin),
        GetSessionMessagesHandler(plugin),
        GetProvidersHandler(plugin),
        ProxyHandler(plugin), // catch-all — must be last
      ];

  /// Routes [request] to the first matching handler and returns its response.
  Future<RelayResponse> route(RelayRequest request) async {
    try {
      for (final handler in _handlers) {
        if (handler.canHandle(request)) {
          final (:pathParams, :queryParams, :fragment) = handler.extractParams(request);
          return await handler.handle(
            request,
            pathParams: pathParams,
            queryParams: queryParams,
            fragment: fragment,
          );
        }
      }
      // Unreachable while ProxyHandler (catch-all) is in the list.
      return RelayMessage.response(
            id: request.id,
            status: 502,
            headers: {},
            body: "no handler found for ${request.method} ${request.path}",
          )
          as RelayResponse;
    } catch (e) {
      return RelayMessage.response(
            id: request.id,
            status: 502,
            headers: {},
            body: "request failed: $e",
          )
          as RelayResponse;
    }
  }
}
