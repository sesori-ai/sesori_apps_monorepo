import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_agent.freezed.dart";

part "plugin_agent.g.dart";

enum PluginAgentMode() {
  all,
  primary,
  subagent,
  unknown,
}

@freezed
sealed class PluginAgentModel with _$PluginAgentModel {
  const factory({
    required String modelID,
    required String providerID,
    required String? variant,
  }) = _PluginAgentModel;
}

@freezed
sealed class PluginAgent with _$PluginAgent {
  const factory({
    required String name,
    required String? description,
    required PluginAgentModel? model,
    required PluginAgentMode mode,
    required bool hidden,
  }) = _PluginAgent;
}
