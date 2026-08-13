import "package:sesori_shared/sesori_shared.dart";

import "../../server/services/bridge_restart_service.dart";
import "request_handler.dart";
import "routed_request.dart";

/// Handles `POST /global/restart` — an explicit, user-triggered bridge restart.
///
/// It validates that a restart can be delivered and returns a typed acceptance.
/// The transport closes or enqueues the fixed response before dispatching the
/// handoff.
class RestartBridgeHandler({required final BridgeRestartService _restartService}) extends RequestHandlerBase {
  this : super(HttpMethod.post, "/global/restart");

  @override
  Future<RoutedRequestOutcome> routeInternal({
    required RelayRequest request,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final bool canRestart = await _restartService.canRestart();
    if (!canRestart) {
      return ResponseOnly(
        response: buildErrorResponse(
          request,
          503,
          "Cannot restart: the managed bridge binary is unavailable. Re-run the install script: https://sesori.com/",
        ),
      );
    }

    return RestartAccepted(requestId: request.id);
  }

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return (await routeInternal(
      request: request,
      pathParams: pathParams,
      queryParams: queryParams,
      fragment: fragment,
    )).response;
  }
}
