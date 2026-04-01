import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../plugin_to_shared_mapping.dart";
import "request_handler.dart";

const _projectIdHeader = "x-project-id";

/// Handles `GET /command` — returns slash commands available to the project.
class GetCommandsHandler extends GetRequestHandler<CommandListResponse> {
  final BridgePlugin _plugin;

  GetCommandsHandler(this._plugin) : super("/command");

  @override
  Future<CommandListResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = findHeader(request.headers, _projectIdHeader);
    final commands = await _plugin.getCommands(projectId: projectId);
    return CommandListResponse(items: commands.map((command) => command.toShared()).toList());
  }
}
