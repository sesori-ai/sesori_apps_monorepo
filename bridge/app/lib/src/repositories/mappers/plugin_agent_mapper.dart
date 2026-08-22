import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginAgentMapper on PluginAgent {
  AgentInfo toAgentInfo() {
    return AgentInfo(
      name: name,
      description: description,
      model: switch (model) {
        PluginAgentModel(:final modelID, :final providerID, :final variant) => AgentModel(
          modelID: modelID,
          providerID: providerID,
          variant: variant,
        ),
        null => null,
      },
      mode: switch (mode) {
        PluginAgentMode.all => AgentMode.all,
        PluginAgentMode.primary => AgentMode.primary,
        PluginAgentMode.subagent => AgentMode.subagent,
        PluginAgentMode.unknown => AgentMode.unknown,
      },
      hidden: hidden,
    );
  }
}
