// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginCommand _$PluginCommandFromJson(Map json) => _PluginCommand(
  name: json['name'] as String,
  template: json['template'] as String?,
  hints:
      (json['hints'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  model: json['model'] as String?,
  provider: json['provider'] as String?,
  source: $enumDecodeNullable(_$PluginCommandSourceEnumMap, json['source']),
  subtask: json['subtask'] as bool?,
);

Map<String, dynamic> _$PluginCommandToJson(_PluginCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'template': ?instance.template,
      'hints': instance.hints,
      'description': ?instance.description,
      'agent': ?instance.agent,
      'model': ?instance.model,
      'provider': ?instance.provider,
      'source': ?_$PluginCommandSourceEnumMap[instance.source],
      'subtask': ?instance.subtask,
    };

const _$PluginCommandSourceEnumMap = {
  PluginCommandSource.command: 'command',
  PluginCommandSource.mcp: 'mcp',
  PluginCommandSource.skill: 'skill',
  PluginCommandSource.unknown: 'unknown',
};

_PluginCommandInvocationContext _$PluginCommandInvocationContextFromJson(
  Map json,
) => _PluginCommandInvocationContext(
  invocationId: json['invocationId'] as String,
  name: json['name'] as String,
  arguments: json['arguments'] as String?,
  acceptedAt: (json['acceptedAt'] as num).toInt(),
  backendMessageId: json['backendMessageId'] as String?,
);

Map<String, dynamic> _$PluginCommandInvocationContextToJson(
  _PluginCommandInvocationContext instance,
) => <String, dynamic>{
  'invocationId': instance.invocationId,
  'name': instance.name,
  'arguments': ?instance.arguments,
  'acceptedAt': instance.acceptedAt,
  'backendMessageId': ?instance.backendMessageId,
};

_PluginCommandDispatch _$PluginCommandDispatchFromJson(Map json) =>
    _PluginCommandDispatch(
      backendMessageId: json['backendMessageId'] as String?,
    );

Map<String, dynamic> _$PluginCommandDispatchToJson(
  _PluginCommandDispatch instance,
) => <String, dynamic>{'backendMessageId': ?instance.backendMessageId};
