import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /session/:id/abort` — aborts in-progress session execution.
class AbortSessionHandler extends BodyRequestHandler<SessionIdRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;
  final void Function(String sessionId) _onSessionAborted;

  AbortSessionHandler(
    this._plugin, {
    required void Function(String sessionId) onSessionAborted,
  }) : _onSessionAborted = onSessionAborted,
       super(
         HttpMethod.post,
         "/session/abort",
         fromJson: SessionIdRequest.fromJson,
       );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    _onSessionAborted(body.sessionId);
    await _plugin.abortSession(sessionId: body.sessionId);
    return const SuccessEmptyResponse();
  }
}
