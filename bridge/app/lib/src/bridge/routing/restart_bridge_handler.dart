import "package:sesori_shared/sesori_shared.dart";

import "../../server/services/bridge_restart_service.dart";
import "models/restart_bridge_response.dart";
import "request_handler.dart";

/// Handles `POST /global/restart` — an explicit, user-triggered bridge restart.
///
/// It validates that a successor can be spawned, replies `{restarting:true}`,
/// and flags the restart. The orchestrator performs the actual spawn + graceful
/// shutdown *after* this reply has been flushed to the phone, so the response is
/// never lost to the handoff.
class RestartBridgeHandler extends RequestHandlerBase {
  RestartBridgeHandler({required BridgeRestartService restartService})
    : _restartService = restartService,
      super(HttpMethod.post, "/global/restart");

  final BridgeRestartService _restartService;

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final bool canSpawn = await _restartService.canSpawnSuccessor();
    if (!canSpawn) {
      return buildErrorResponse(
        request,
        503,
        "Cannot restart: the managed bridge binary is unavailable. Re-run the install script: https://sesori.com/",
      );
    }

    _restartService.requestRestart();
    return buildOkJsonResponse(request, const RestartBridgeResponse(restarting: true));
  }
}
