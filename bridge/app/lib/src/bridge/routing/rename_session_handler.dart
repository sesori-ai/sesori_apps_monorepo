import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler extends BodyRequestHandler<RenameSessionRequest, Session> {
  final BridgePlugin _plugin;
  final SessionRepository _sessionRepository;

  RenameSessionHandler({required BridgePlugin plugin, required SessionRepository sessionRepository})
    : _plugin = plugin,
      _sessionRepository = sessionRepository,
      super(HttpMethod.patch, "/session/title", fromJson: RenameSessionRequest.fromJson);

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
    return _sessionRepository.enrichPluginSession(pluginSession: updated);
  }
}
