import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../plugin_to_shared_mapping.dart";
import "request_handler.dart";

/// Handles `POST /command` — returns slash commands available to the project.
class GetCommandsHandler extends BodyRequestHandler<ProjectIdRequest, CommandListResponse> {
  final BridgePlugin _plugin;

  GetCommandsHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/command",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<CommandListResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    final commands = await _plugin.getCommands(projectId: projectId);
    return CommandListResponse(items: commands.map((command) => command.toShared()).toList());
  }
}
