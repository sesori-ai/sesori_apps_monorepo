import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin;
import "package:sesori_shared/sesori_shared.dart" show CommandListResponse;

import "mappers/plugin_command_mapper.dart";

class CommandRepository {
  final BridgePlugin _plugin;

  CommandRepository({required BridgePlugin plugin}) : _plugin = plugin;

  Future<CommandListResponse> getCommands({required String? projectId}) async {
    final normalizedProjectId = projectId?.trim();
    final commands = await _plugin.getCommands(
      projectId: normalizedProjectId == null || normalizedProjectId.isEmpty ? null : normalizedProjectId,
    );
    return CommandListResponse(
      items: commands.map((command) => command.toSharedCommandInfo()).toList(growable: false),
    );
  }
}
