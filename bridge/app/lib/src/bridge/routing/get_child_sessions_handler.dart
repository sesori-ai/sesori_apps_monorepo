import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_session_mapper.dart";
import "request_handler.dart";

/// Handles `GET /session/:id/children` — returns direct child sessions.
class GetChildSessionsHandler extends BodyRequestHandler<SessionIdRequest, SessionListResponse> {
  final BridgePlugin _plugin;

  GetChildSessionsHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/session/children",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionListResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final pluginSessions = await _plugin.getChildSessions(sessionId);

    final sessions = pluginSessions.map((s) => s.toSharedSession()).toList();

    return SessionListResponse(items: sessions);
  }
}
