import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show Agents;

import "mappers/plugin_agent_mapper.dart";

class AgentRepository {
  final BridgePluginApi _plugin;

  AgentRepository({required BridgePluginApi plugin}) : _plugin = plugin;

  Future<Agents> getAgents() async {
    final pluginAgents = await _plugin.getAgents();
    final agents = pluginAgents.map((a) => a.toAgentInfo()).toList();
    return Agents(agents: agents);
  }
}
