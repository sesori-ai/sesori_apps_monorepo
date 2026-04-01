// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommandInfo _$CommandInfoFromJson(Map json) => _CommandInfo(
  name: json['name'] as String,
  template: json['template'] as String?,
  hints: (json['hints'] as List<dynamic>?)?.map((e) => e as String).toList(),
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  model: json['model'] as String?,
  source: $enumDecodeNullable(
    _$CommandSourceEnumMap,
    json['source'],
    unknownValue: CommandSource.unknown,
  ),
  subtask: json['subtask'] as bool?,
);

Map<String, dynamic> _$CommandInfoToJson(_CommandInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'template': instance.template,
      'hints': instance.hints,
      'description': instance.description,
      'agent': instance.agent,
      'model': instance.model,
      'source': _$CommandSourceEnumMap[instance.source],
      'subtask': instance.subtask,
    };

const _$CommandSourceEnumMap = {
  CommandSource.command: 'command',
  CommandSource.mcp: 'mcp',
  CommandSource.skill: 'skill',
  CommandSource.unknown: 'unknown',
};
