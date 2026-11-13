// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_invocation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommandInvocation _$CommandInvocationFromJson(Map json) => _CommandInvocation(
  name: json['name'] as String,
  source: $enumDecode(
    _$CommandSourceEnumMap,
    json['source'],
    unknownValue: CommandSource.unknown,
  ),
  arguments: json['arguments'] as String?,
);

Map<String, dynamic> _$CommandInvocationToJson(_CommandInvocation instance) =>
    <String, dynamic>{
      'name': instance.name,
      'source': _$CommandSourceEnumMap[instance.source]!,
      'arguments': ?instance.arguments,
    };

const _$CommandSourceEnumMap = {
  CommandSource.command: 'command',
  CommandSource.mcp: 'mcp',
  CommandSource.skill: 'skill',
  CommandSource.unknown: 'unknown',
};
