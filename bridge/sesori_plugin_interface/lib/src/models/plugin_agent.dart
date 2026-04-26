import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_agent.freezed.dart";

part "plugin_agent.g.dart";

enum PluginAgentMode {
  all,
  primary,
  subagent,
  unknown,
}

enum PluginAgentVariant {
  none("none"),
  minimal("minimal"),
  low("low"),
  medium("medium"),
  high("high"),
  xhigh("xhigh")
  ;

  const PluginAgentVariant(this.safeName);
  final String safeName;

  /// Parses a raw string into a [PluginAgentVariant], or returns `null`
  /// if the value doesn't match any known variant.
  static PluginAgentVariant? tryParse(String? value) => switch (value) {
    "none" => none,
    "minimal" => minimal,
    "low" => low,
    "medium" => medium,
    "high" => high,
    "xhigh" => xhigh,
    _ => null,
  };
}

@freezed
sealed class PluginAgentModel with _$PluginAgentModel {
  const factory PluginAgentModel({
    required String modelID,
    required String providerID,
    required String? variant,
  }) = _PluginAgentModel;
}

@freezed
sealed class PluginAgent with _$PluginAgent {
  const factory PluginAgent({
    required String name,
    required String? description,
    required PluginAgentModel? model,
    required PluginAgentMode mode,
    required bool hidden,
  }) = _PluginAgent;
}
