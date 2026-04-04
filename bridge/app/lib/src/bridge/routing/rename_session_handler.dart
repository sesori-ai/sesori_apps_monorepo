import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/plugin_session_mapper.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler extends BodyRequestHandler<RenameSessionRequest, Session> {
  final BridgePlugin _plugin;

  RenameSessionHandler(this._plugin)
    : super(HttpMethod.patch, "/session/title", fromJson: RenameSessionRequest.fromJson);

  @override
  Future<Session> handle(
    RelayRequest request, {
    required RenameSessionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (body.sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    final updated = await _plugin.renameSession(
      sessionId: body.sessionId,
      title: body.title,
    );
    return updated.toSharedSession();
  }
}
