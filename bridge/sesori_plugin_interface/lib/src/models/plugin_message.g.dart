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
      'snapshot': instance.snapshot,
      'time': instance.time?.toJson(),
    };

Map<String, dynamic> _$PluginToolStateToJson(_PluginToolState instance) =>
    <String, dynamic>{
      'status': instance.status,
      'title': instance.title,
      'output': instance.output,
      'error': instance.error,
    };

Map<String, dynamic> _$PluginPartTimeToJson(_PluginPartTime instance) =>
    <String, dynamic>{'start': instance.start, 'end': instance.end};

Map<String, dynamic> _$PluginMessageToJson(_PluginMessage instance) =>
    <String, dynamic>{
      'role': instance.role,
      'id': instance.id,
      'sessionID': instance.sessionID,
      'parentID': instance.parentID,
      'agent': instance.agent,
      'modelID': instance.modelID,
      'providerID': instance.providerID,
      'cost': instance.cost,
      'time': instance.time?.toJson(),
      'finish': instance.finish,
    };

Map<String, dynamic> _$PluginMessageTimeToJson(_PluginMessageTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'completed': instance.completed,
    };
