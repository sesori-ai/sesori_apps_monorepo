// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationData _$NotificationDataFromJson(Map json) => _NotificationData(
  category: $enumDecode(_$NotificationCategoryEnumMap, json['category']),
  sessionId: json['sessionId'] as String?,
  eventType: json['eventType'] as String?,
);

Map<String, dynamic> _$NotificationDataToJson(_NotificationData instance) =>
    <String, dynamic>{
      'category': _$NotificationCategoryEnumMap[instance.category]!,
      'sessionId': instance.sessionId,
      'eventType': instance.eventType,
    };

const _$NotificationCategoryEnumMap = {
  NotificationCategory.aiInteraction: 'ai_interaction',
  NotificationCategory.sessionMessage: 'session_message',
  NotificationCategory.connectionStatus: 'connection_status',
  NotificationCategory.systemUpdate: 'system_update',
};
