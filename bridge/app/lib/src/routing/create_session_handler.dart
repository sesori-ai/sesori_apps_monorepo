import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";

import "../services/session_creation_service.dart";
import "../services/stale_session_prompt_options_exception.dart";
import "request_handler.dart";

class CreateSessionHandler({
  required final SessionCreationService _sessionCreationService,
  required final Future<void> Function({required String pluginId, required String projectId})
  _invalidateRejectedSelection,
}) extends BodyRequestHandler<CreateSessionRequest, Session> {
  this
    : super(
        HttpMethod.post,
        "/session/create",
        fromJson: CreateSessionRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required CreateSessionRequest body,
  }) async {
    try {
      return await _sessionCreationService.createSession(request: body);
    } on PluginStaleOptionsException catch (error, stackTrace) {
      try {
        await _invalidateRejectedSelection(pluginId: body.pluginId, projectId: body.projectId);
      } on Object catch (invalidationError, invalidationStackTrace) {
        Log.w("Failed to invalidate stale options after session creation", invalidationError, invalidationStackTrace);
      }
      throw StaleSessionPromptOptionsException(cause: error, causeStackTrace: stackTrace);
    }
  }
}
