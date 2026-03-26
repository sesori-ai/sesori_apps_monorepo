// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map json) => _Message(
  role: json['role'] as String,
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  modelID: json['modelID'] as String?,
  providerID: json['providerID'] as String?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'role': instance.role,
  'id': instance.id,
  'sessionID': instance.sessionID,
  'agent': instance.agent,
  'modelID': instance.modelID,
  'providerID': instance.providerID,
};
