import "package:freezed_annotation/freezed_annotation.dart";

import "agent_mode.dart";

part "agent_info.freezed.dart";

part "agent_info.g.dart";

/// Represents an agent available for session creation.
///
/// We only model the fields relevant for the mobile picker UI.
@Freezed(fromJson: true, toJson: true)
sealed class Agents with _$Agents {
  const factory({
    required List<AgentInfo> agents,
  }) = _Agents;

  factory fromJson(Map<String, dynamic> json) => _$AgentsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class AgentInfo with _$AgentInfo {
  const factory({
    required String name,
    required String? description,
    required AgentModel? model,
    @JsonKey(unknownEnumValue: AgentMode.unknown) required AgentMode mode,
    @Default(false) bool hidden,
  }) = _AgentInfo;

  factory fromJson(Map<String, dynamic> json) => _$AgentInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class AgentModel with _$AgentModel {
  const factory({
    required String modelID,
    required String providerID,
    required String? variant,
  }) = _AgentModel;

  factory fromJson(Map<String, dynamic> json) => _$AgentModelFromJson(json);
}
