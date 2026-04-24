// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginMessageWithPartsToJson(
  _PluginMessageWithParts instance,
) => <String, dynamic>{
  'info': instance.info.toJson(),
  'parts': instance.parts.map((e) => e.toJson()).toList(),
};

Map<String, dynamic> _$PluginMessagePartToJson(_PluginMessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': _$PluginMessagePartTypeEnumMap[instance.type]!,
      'text': instance.text,
      'tool': instance.tool,
      'state': instance.state?.toJson(),
      'prompt': instance.prompt,
      'description': instance.description,
      'agent': instance.agent,
      'agentName': instance.agentName,
      'attempt': instance.attempt,
      'retryError': instance.retryError,
    };

const _$PluginMessagePartTypeEnumMap = {
  PluginMessagePartType.text: 'text',
  PluginMessagePartType.reasoning: 'reasoning',
  PluginMessagePartType.tool: 'tool',
  PluginMessagePartType.subtask: 'subtask',
  PluginMessagePartType.stepStart: 'step-start',
  PluginMessagePartType.stepFinish: 'step-finish',
  PluginMessagePartType.file: 'file',
  PluginMessagePartType.snapshot: 'snapshot',
  PluginMessagePartType.patch: 'patch',
  PluginMessagePartType.agent: 'agent',
  PluginMessagePartType.retry: 'retry',
  PluginMessagePartType.compaction: 'compaction',
  PluginMessagePartType.unknown: 'unknown',
};

Map<String, dynamic> _$PluginToolStateToJson(_PluginToolState instance) =>
    <String, dynamic>{
      'status': instance.status,
      'title': instance.title,
      'output': instance.output,
      'error': instance.error,
    };

Map<String, dynamic> _$PluginMessageToJson(_PluginMessage instance) =>
    <String, dynamic>{
      'role': instance.role,
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': instance.agent,
      'modelID': instance.modelID,
      'providerID': instance.providerID,
      'error': instance.error?.toJson(),
    };

Map<String, dynamic> _$PluginMessageErrorToJson(_PluginMessageError instance) =>
    <String, dynamic>{'name': instance.name, 'message': instance.message};
