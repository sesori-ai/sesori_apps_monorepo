import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /session/:id/abort` — aborts in-progress session execution.
class AbortSessionHandler extends BodyRequestHandler<SessionIdRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  AbortSessionHandler(this._plugin)
    : super(
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
    await _plugin.abortSession(sessionId: body.sessionId);
    return const SuccessEmptyResponse();
  }
}
