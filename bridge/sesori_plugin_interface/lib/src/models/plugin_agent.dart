import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_agent.freezed.dart";

part "plugin_agent.g.dart";

enum PluginAgentMode {
  all,
  primary,
  subagent,
  unknown,
}

@freezed
sealed class PluginAgentModel with _$PluginAgentModel {
  const factory PluginAgentModel({
    required String modelID,
    required String providerID,
  }) = _PluginAgentModel;
}

@freezed
sealed class PluginAgent with _$PluginAgent {
  const factory PluginAgent({
    required String name,
    required String? description,
    required PluginAgentModel? model,
    required String? variant,
    required PluginAgentMode mode,
    required bool hidden,
  }) = _PluginAgent;
}
