import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgePluginApi, PluginAgent, PluginAgentMode, PluginAgentModel;
import "package:sesori_shared/sesori_shared.dart" show Agents;

import "../api/codex_defaults_api.dart";
import "mappers/plugin_agent_mapper.dart";

class AgentRepository {
  final BridgePluginApi _plugin;
  final CodexDefaultsApi _codexDefaultsApi;

  AgentRepository({
    required BridgePluginApi plugin,
    required CodexDefaultsApi codexDefaultsApi,
  }) : _plugin = plugin,
       _codexDefaultsApi = codexDefaultsApi;

  Future<Agents> getAgents() async {
    final pluginAgents = await _plugin.getAgents();
    String? codexProjectId;
    if (pluginAgents.isEmpty && _plugin.id == "codex") {
      try {
        final projects = await _plugin.getProjects();
        if (projects.isNotEmpty) {
          codexProjectId = projects.first.id;
        }
      } catch (_) {
        codexProjectId = null;
      }
    }
    final effectiveAgents = pluginAgents.isNotEmpty || _plugin.id != "codex"
        ? pluginAgents
        : [
            switch (_codexDefaultsApi.readProjectDefaults(projectId: codexProjectId ?? "")) {
              CodexSelectionDefaults(:final agent, :final modelId, :final modelProvider) => PluginAgent(
                name: agent,
                description: "Codex CLI session",
                model: switch ((modelId, modelProvider)) {
                  (final modelID?, final providerID?) => PluginAgentModel(
                    modelID: modelID,
                    providerID: providerID,
                    variant: null,
                  ),
                  _ => null,
                },
                mode: PluginAgentMode.primary,
                hidden: false,
              ),
            },
          ];
    final agents = effectiveAgents.map((a) => a.toAgentInfo()).toList();
    return Agents(agents: agents);
  }
}
