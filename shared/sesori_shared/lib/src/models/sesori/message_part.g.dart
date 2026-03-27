// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessagePart _$MessagePartFromJson(Map json) => _MessagePart(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  type: $enumDecode(_$MessagePartTypeEnumMap, json['type']),
  text: json['text'] as String?,
  tool: json['tool'] as String?,
  state: json['state'] == null
      ? null
      : ToolState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
  prompt: json['prompt'] as String?,
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  agentName: json['agentName'] as String?,
  attempt: (json['attempt'] as num?)?.toInt(),
  retryError: json['retryError'] as String?,
);

Map<String, dynamic> _$MessagePartToJson(_MessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': _$MessagePartTypeEnumMap[instance.type]!,
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

const _$MessagePartTypeEnumMap = {
  MessagePartType.text: 'text',
  MessagePartType.reasoning: 'reasoning',
  MessagePartType.tool: 'tool',
  MessagePartType.subtask: 'subtask',
  MessagePartType.stepStart: 'step-start',
  MessagePartType.stepFinish: 'step-finish',
  MessagePartType.file: 'file',
  MessagePartType.snapshot: 'snapshot',
  MessagePartType.patch: 'patch',
  MessagePartType.agent: 'agent',
  MessagePartType.retry: 'retry',
  MessagePartType.compaction: 'compaction',
};

_ToolState _$ToolStateFromJson(Map json) => _ToolState(
  status: json['status'] as String,
  title: json['title'] as String?,
  output: json['output'] as String?,
  error: json['error'] as String?,
);

Map<String, dynamic> _$ToolStateToJson(_ToolState instance) =>
    <String, dynamic>{
      'status': instance.status,
      'title': instance.title,
      'output': instance.output,
      'error': instance.error,
    };
