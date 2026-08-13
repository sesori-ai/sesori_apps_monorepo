import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";
import "routed_request.dart";

/// Routes incoming [RelayRequest]s to the first matching [RequestHandlerBase].
///
/// Handlers are checked in registration order. The first matching handler wins.
///
/// Error handling is centralised here: any exception thrown by a handler is
/// converted to a `502` response so callers never have to deal with routing
/// failures.
class RequestRouter({
  required List<RequestHandlerBase> handlers,
}) {
  final List<RequestHandlerBase> _handlers = List<RequestHandlerBase>.unmodifiable(handlers);

  /// Selects a route synchronously and returns its asynchronous completion.
  PendingRoutedRequest route({required RelayRequest request}) {
    final requestMethod = HttpMethod.parseExternal(rawMethod: request.method);
    if (requestMethod == null) {
      return PendingRoutedRequest(
        routeIdentity: const InvalidMethodRoute(),
        completion: Future<RoutedRequestOutcome>.value(ResponseOnly(response: _notFound(request))),
      );
    }

    final Uri target;
    try {
      target = Uri.parse(request.path);
    } on Object catch (error) {
      return PendingRoutedRequest(
        routeIdentity: InvalidTargetRoute(method: requestMethod),
        completion: Future<RoutedRequestOutcome>.value(
          ResponseOnly(
            response: _failed(request: request, error: error),
          ),
        ),
      );
    }

    for (final handler in _handlers) {
      if (handler.matches(requestMethod: requestMethod, target: target)) {
        final identity = MatchedRoute(method: requestMethod, pathTemplate: handler.path);
        return PendingRoutedRequest(
          routeIdentity: identity,
          completion: _complete(
            request: request,
            target: target,
            handler: handler,
            identity: identity,
          ),
        );
      }
    }

    return PendingRoutedRequest(
      routeIdentity: UnmatchedRoute(method: requestMethod),
      completion: Future<RoutedRequestOutcome>.value(ResponseOnly(response: _notFound(request))),
    );
  }

  Future<RoutedRequestOutcome> _complete({
    required RelayRequest request,
    required Uri target,
    required RequestHandlerBase handler,
    required MatchedRoute identity,
  }) async {
    try {
      final (:pathParams, :queryParams, :fragment) = handler.extractTargetParams(target: target);
      return await handler.routeInternal(
        request: request,
        pathParams: pathParams,
        queryParams: queryParams,
        fragment: fragment,
      );
    } on PluginOperationException catch (error, stackTrace) {
      Log.w("${identity.diagnosticLabel}: upstream error", error, stackTrace);
      return ResponseOnly(
        response: RelayResponse(
          id: request.id,
          status: error.statusCode ?? 502,
          headers: const {},
          body: error.toString(),
        ),
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "${identity.diagnosticLabel}: routing failed for ${request.method} ${request.path}",
        error,
        stackTrace,
      );
      return ResponseOnly(
        response: _failed(request: request, error: error),
      );
    }
  }

  RelayResponse _notFound(RelayRequest request) => RelayResponse(
    id: request.id,
    status: 404,
    headers: const {},
    body: "no handler found for ${request.method} ${request.path}",
  );

  RelayResponse _failed({required RelayRequest request, required Object error}) {
    return RelayResponse(
      id: request.id,
      status: 502,
      headers: const {},
      body: "request failed: $error",
    );
  }
}
