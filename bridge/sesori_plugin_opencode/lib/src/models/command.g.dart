// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Command _$CommandFromJson(Map json) => _Command(
  name: json['name'] as String,
  template: _readTemplate(json, 'template') as String?,
  hints:
      (json['hints'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  model: json['model'] as String?,
  provider: json['provider'] as String?,
  source: $enumDecodeNullable(
    _$CommandSourceEnumMap,
    json['source'],
    unknownValue: CommandSource.unknown,
  ),
  subtask: json['subtask'] as bool?,
);

Map<String, dynamic> _$CommandToJson(_Command instance) => <String, dynamic>{
  'name': instance.name,
  'template': instance.template,
  'hints': instance.hints,
  'description': instance.description,
  'agent': instance.agent,
  'model': instance.model,
  'provider': instance.provider,
  'source': _$CommandSourceEnumMap[instance.source],
  'subtask': instance.subtask,
};

const _$CommandSourceEnumMap = {
  CommandSource.command: 'command',
  CommandSource.mcp: 'mcp',
  CommandSource.skill: 'skill',
  CommandSource.unknown: 'unknown',
};
