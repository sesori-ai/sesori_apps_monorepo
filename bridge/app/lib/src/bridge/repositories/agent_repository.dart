import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show Agents, StringExtensions;

import "mappers/plugin_agent_mapper.dart";

class AgentRepository {
  final BridgePluginApi _plugin;

  AgentRepository({required BridgePluginApi plugin}) : _plugin = plugin;

  Future<Agents> getAgents({required String? projectId}) async {
    // A null/blank projectId comes from the deprecated GET /agent route,
    // which carries no project context. Fall back to the bridge CWD, which
    // plugins treat as the active project.
    final resolvedProjectId = projectId?.normalize() ?? io.Directory.current.path;
    final pluginAgents = await _plugin.getAgents(projectId: resolvedProjectId);
    final agents = pluginAgents.map((a) => a.toAgentInfo()).toList();
    return Agents(agents: agents);
  }
}
