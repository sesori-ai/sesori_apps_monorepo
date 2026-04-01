// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginCommand _$PluginCommandFromJson(Map json) => _PluginCommand(
  name: json['name'] as String,
  template: json['template'] as String,
  hints: (json['hints'] as List<dynamic>).map((e) => e as String).toList(),
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  model: json['model'] as String?,
  source: $enumDecodeNullable(_$PluginCommandSourceEnumMap, json['source']),
  subtask: json['subtask'] as bool?,
);

Map<String, dynamic> _$PluginCommandToJson(_PluginCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'template': instance.template,
      'hints': instance.hints,
      'description': instance.description,
      'agent': instance.agent,
      'model': instance.model,
      'source': _$PluginCommandSourceEnumMap[instance.source],
      'subtask': instance.subtask,
    };

const _$PluginCommandSourceEnumMap = {
  PluginCommandSource.command: 'command',
  PluginCommandSource.mcp: 'mcp',
  PluginCommandSource.skill: 'skill',
  PluginCommandSource.unknown: 'unknown',
};
