import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `POST /command` — returns slash commands available to the project.
class GetCommandsHandler({required final SessionRepository _sessionRepository})
    extends BodyRequestHandler<PluginProjectIdRequest, CommandListResponse> {
  this
    : super(
        HttpMethod.post,
        "/command",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<CommandListResponse> handle(
    RelayRequest request, {
    required PluginProjectIdRequest body,
  }) async {
    return await _sessionRepository.getCommands(
      projectId: body.projectId,
      pluginId: body.pluginId,
    );
  }
}
