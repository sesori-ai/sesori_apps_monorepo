// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Agents _$AgentsFromJson(Map json) => _Agents(
  agents: (json['agents'] as List<dynamic>)
      .map((e) => AgentInfo.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$AgentsToJson(_Agents instance) => <String, dynamic>{
  'agents': instance.agents.map((e) => e.toJson()).toList(),
};

_AgentInfo _$AgentInfoFromJson(Map json) => _AgentInfo(
  name: json['name'] as String,
  description: json['description'] as String?,
  model: json['model'] == null
      ? null
      : AgentModel.fromJson(Map<String, dynamic>.from(json['model'] as Map)),
  variant: json['variant'] as String?,
  mode: $enumDecode(
    _$AgentModeEnumMap,
    json['mode'],
    unknownValue: AgentMode.unknown,
  ),
  hidden: json['hidden'] as bool? ?? false,
);

Map<String, dynamic> _$AgentInfoToJson(_AgentInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'model': instance.model?.toJson(),
      'variant': instance.variant,
      'mode': _$AgentModeEnumMap[instance.mode]!,
      'hidden': instance.hidden,
    };

const _$AgentModeEnumMap = {
  AgentMode.all: 'all',
  AgentMode.primary: 'primary',
  AgentMode.subagent: 'subagent',
  AgentMode.unknown: 'unknown',
};

_AgentModel _$AgentModelFromJson(Map json) => _AgentModel(
  modelID: json['modelID'] as String,
  providerID: json['providerID'] as String,
);

Map<String, dynamic> _$AgentModelToJson(_AgentModel instance) =>
    <String, dynamic>{
      'modelID': instance.modelID,
      'providerID': instance.providerID,
    };
