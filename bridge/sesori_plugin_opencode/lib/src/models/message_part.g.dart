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
  callID: json['callID'] as String?,
  state: json['state'] == null
      ? null
      : ToolState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
  mime: json['mime'] as String?,
  url: json['url'] as String?,
  filename: json['filename'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  reason: json['reason'] as String?,
  prompt: json['prompt'] as String?,
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  name: json['name'] as String?,
  attempt: (json['attempt'] as num?)?.toInt(),
  error: (json['error'] as Map?)?.map((k, e) => MapEntry(k as String, e)),
  snapshot: json['snapshot'] as String?,
  time: json['time'] == null
      ? null
      : PartTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
);

Map<String, dynamic> _$MessagePartToJson(_MessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': instance.type,
      'text': instance.text,
      'tool': instance.tool,
      'callID': instance.callID,
      'state': instance.state?.toJson(),
      'mime': instance.mime,
      'url': instance.url,
      'filename': instance.filename,
      'cost': instance.cost,
      'reason': instance.reason,
      'prompt': instance.prompt,
      'description': instance.description,
      'agent': instance.agent,
      'name': instance.name,
      'attempt': instance.attempt,
      'error': instance.error,
      'snapshot': instance.snapshot,
      'time': instance.time?.toJson(),
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

_PartTime _$PartTimeFromJson(Map json) => _PartTime(
  start: (json['start'] as num?)?.toInt(),
  end: (json['end'] as num?)?.toInt(),
);

Map<String, dynamic> _$PartTimeToJson(_PartTime instance) => <String, dynamic>{
  'start': instance.start,
  'end': instance.end,
};
