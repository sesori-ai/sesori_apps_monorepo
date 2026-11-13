// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_command_invocation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginCommandInvocationToJson(
  _PluginCommandInvocation instance,
) => <String, dynamic>{
  'name': instance.name,
  'source': _$PluginCommandSourceEnumMap[instance.source]!,
  'arguments': ?instance.arguments,
};

const _$PluginCommandSourceEnumMap = {
  PluginCommandSource.command: 'command',
  PluginCommandSource.mcp: 'mcp',
  PluginCommandSource.skill: 'skill',
  PluginCommandSource.unknown: 'unknown',
};
