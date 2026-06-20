// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageUser _$MessageUserFromJson(Map json) => MessageUser(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  time: json['time'] == null
      ? null
      : MessageTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  $type: json['role'] as String?,
);

Map<String, dynamic> _$MessageUserToJson(MessageUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

MessageAssistant _$MessageAssistantFromJson(Map json) => MessageAssistant(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  modelID: json['modelID'] as String?,
  providerID: json['providerID'] as String?,
  time: json['time'] == null
      ? null
      : MessageTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  $type: json['role'] as String?,
);

Map<String, dynamic> _$MessageAssistantToJson(MessageAssistant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'modelID': ?instance.modelID,
      'providerID': ?instance.providerID,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

MessageError _$MessageErrorFromJson(Map json) => MessageError(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  modelID: json['modelID'] as String?,
  providerID: json['providerID'] as String?,
  errorName: json['errorName'] as String,
  errorMessage: json['errorMessage'] as String,
  time: json['time'] == null
      ? null
      : MessageTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  $type: json['role'] as String?,
);

Map<String, dynamic> _$MessageErrorToJson(MessageError instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'modelID': ?instance.modelID,
      'providerID': ?instance.providerID,
      'errorName': instance.errorName,
      'errorMessage': instance.errorMessage,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

_MessageTime _$MessageTimeFromJson(Map json) => _MessageTime(
  created: (json['created'] as num).toInt(),
  completed: (json['completed'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageTimeToJson(_MessageTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'completed': ?instance.completed,
    };
