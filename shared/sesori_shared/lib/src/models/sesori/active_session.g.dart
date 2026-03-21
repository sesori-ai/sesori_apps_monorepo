// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActiveSession _$ActiveSessionFromJson(Map json) => _ActiveSession(
  id: json['id'] as String,
  mainAgentRunning: json['mainAgentRunning'] as bool? ?? false,
  childSessionIds:
      (json['childSessionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ActiveSessionToJson(_ActiveSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mainAgentRunning': instance.mainAgentRunning,
      'childSessionIds': instance.childSessionIds,
    };
