// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActiveSession _$ActiveSessionFromJson(Map json) => _ActiveSession(
  id: json['id'] as String,
  mainAgentRunning: json['mainAgentRunning'] as bool? ?? false,
  awaitingInput: json['awaitingInput'] as bool? ?? false,
  childSessionIds:
      (json['childSessionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  isRetrying: json['isRetrying'] as bool? ?? false,
  lastUserActivityAt: (json['lastUserActivityAt'] as num?)?.toInt(),
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
  sending: json['sending'] == null
      ? null
      : ActiveSessionSending.fromJson(
          Map<String, dynamic>.from(json['sending'] as Map),
        ),
);

Map<String, dynamic> _$ActiveSessionToJson(_ActiveSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mainAgentRunning': instance.mainAgentRunning,
      'awaitingInput': instance.awaitingInput,
      'childSessionIds': instance.childSessionIds,
      'isRetrying': instance.isRetrying,
      'lastUserActivityAt': ?instance.lastUserActivityAt,
      'updatedAt': ?instance.updatedAt,
      'sending': ?instance.sending?.toJson(),
    };

_ActiveSessionSending _$ActiveSessionSendingFromJson(Map json) =>
    _ActiveSessionSending(targetTitle: json['targetTitle'] as String?);

Map<String, dynamic> _$ActiveSessionSendingToJson(
  _ActiveSessionSending instance,
) => <String, dynamic>{'targetTitle': ?instance.targetTitle};
