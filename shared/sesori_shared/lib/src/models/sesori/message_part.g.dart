// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessagePart _$MessagePartFromJson(Map json) => _MessagePart(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  type: json['type'] as String,
  text: json['text'] as String?,
  tool: json['tool'] as String?,
  state: json['state'] == null
      ? null
      : ToolState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
  prompt: json['prompt'] as String?,
  description: json['description'] as String?,
  agent: json['agent'] as String?,
);

Map<String, dynamic> _$MessagePartToJson(_MessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': instance.type,
      'text': instance.text,
      'tool': instance.tool,
      'state': instance.state?.toJson(),
      'prompt': instance.prompt,
      'description': instance.description,
      'agent': instance.agent,
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
