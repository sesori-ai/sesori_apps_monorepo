import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `POST /command` — returns slash commands available to the project.
class GetCommandsHandler extends BodyRequestHandler<PluginProjectIdRequest, CommandListResponse> {
  final SessionRepository _sessionRepository;

  GetCommandsHandler({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository,
      super(
        HttpMethod.post,
        "/command",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<CommandListResponse> handle(
    RelayRequest request, {
    required PluginProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _sessionRepository.getCommands(
      projectId: body.projectId,
      pluginId: body.pluginId == legacyMissingPluginId ? _sessionRepository.pluginId : body.pluginId,
    );
  }
}
