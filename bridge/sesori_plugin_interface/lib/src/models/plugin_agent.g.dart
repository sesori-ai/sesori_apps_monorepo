// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_agent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginAgentModelToJson(_PluginAgentModel instance) =>
    <String, dynamic>{
      'modelID': instance.modelID,
      'providerID': instance.providerID,
    };

Map<String, dynamic> _$PluginAgentToJson(_PluginAgent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'model': instance.model?.toJson(),
      'variant': _$PluginAgentVariantEnumMap[instance.variant],
      'mode': _$PluginAgentModeEnumMap[instance.mode]!,
      'hidden': instance.hidden,
    };

const _$PluginAgentVariantEnumMap = {
  PluginAgentVariant.none: 'none',
  PluginAgentVariant.minimal: 'minimal',
  PluginAgentVariant.low: 'low',
  PluginAgentVariant.medium: 'medium',
  PluginAgentVariant.high: 'high',
  PluginAgentVariant.xhigh: 'xhigh',
};

const _$PluginAgentModeEnumMap = {
  PluginAgentMode.all: 'all',
  PluginAgentMode.primary: 'primary',
  PluginAgentMode.subagent: 'subagent',
  PluginAgentMode.unknown: 'unknown',
};
