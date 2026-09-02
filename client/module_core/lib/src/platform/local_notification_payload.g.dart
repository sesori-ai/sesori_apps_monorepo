// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LocalNotificationPayload _$LocalNotificationPayloadFromJson(Map json) =>
    _LocalNotificationPayload(
      sessionId: json['sessionId'] as String?,
      projectId: json['projectId'] as String?,
      sessionTitle: json['sessionTitle'] as String?,
    );

Map<String, dynamic> _$LocalNotificationPayloadToJson(
  _LocalNotificationPayload instance,
) => <String, dynamic>{
  'sessionId': ?instance.sessionId,
  'projectId': ?instance.projectId,
  'sessionTitle': ?instance.sessionTitle,
};
