import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "agent_mode.dart";

part "agent_info.freezed.dart";

part "agent_info.g.dart";

/// Represents an available agent from `GET /agent`.
///
/// We only model the fields relevant for the mobile picker UI.
@Freezed(fromJson: true, toJson: true)
sealed class AgentInfo with _$AgentInfo {
  const factory AgentInfo({
    required String name,
    String? description,
    AgentModel? model,
    String? variant,
    @JsonKey(unknownEnumValue: AgentMode.unknown) required AgentMode mode,
    @Default(false) bool hidden,
  }) = _AgentInfo;

  factory AgentInfo.fromJson(Map<String, dynamic> json) => _$AgentInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class AgentModel with _$AgentModel {
  const factory AgentModel({
    required String modelID,
    required String providerID,
  }) = _AgentModel;

  factory AgentModel.fromJson(Map<String, dynamic> json) => _$AgentModelFromJson(json);
}

extension AgentInfoToPluginExtension on AgentInfo {
  PluginAgent toPlugin() {
    return PluginAgent(
      name: name,
      description: description,
      model: switch (model) {
        AgentModel(:final modelID, :final providerID) => PluginAgentModel(
          modelID: modelID,
          providerID: providerID,
        ),
        null => null,
      },
      variant: PluginAgentVariant.tryParse(variant),
      mode: switch (mode) {
        AgentMode.all => PluginAgentMode.all,
        AgentMode.primary => PluginAgentMode.primary,
        AgentMode.subagent => PluginAgentMode.subagent,
        AgentMode.unknown => PluginAgentMode.unknown,
      },
      hidden: hidden,
    );
  }
}
