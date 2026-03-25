// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationData _$NotificationDataFromJson(Map json) => _NotificationData(
  category: $enumDecode(
    _$NotificationCategoryEnumMap,
    json['category'],
    unknownValue: NotificationCategory.unknown,
  ),
  eventType: $enumDecodeNullable(
    _$NotificationEventTypeEnumMap,
    json['eventType'],
    unknownValue: NotificationEventType.unknown,
  ),
  sessionId: json['sessionId'] as String?,
);

Map<String, dynamic> _$NotificationDataToJson(_NotificationData instance) =>
    <String, dynamic>{
      'category': _$NotificationCategoryEnumMap[instance.category]!,
      'eventType': _$NotificationEventTypeEnumMap[instance.eventType],
      'sessionId': instance.sessionId,
    };

const _$NotificationCategoryEnumMap = {
  NotificationCategory.aiInteraction: 'ai_interaction',
  NotificationCategory.sessionMessage: 'session_message',
  NotificationCategory.connectionStatus: 'connection_status',
  NotificationCategory.systemUpdate: 'system_update',
  NotificationCategory.unknown: 'unknown',
};

const _$NotificationEventTypeEnumMap = {
  NotificationEventType.questionAsked: 'question_asked',
  NotificationEventType.permissionAsked: 'permission_asked',
  NotificationEventType.installationUpdateAvailable:
      'installation_update_available',
  NotificationEventType.agentTurnCompleted: 'agent_turn_completed',
  NotificationEventType.unknown: 'unknown',
};
