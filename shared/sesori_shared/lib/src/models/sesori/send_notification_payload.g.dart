// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendNotificationPayload _$SendNotificationPayloadFromJson(Map json) =>
    _SendNotificationPayload(
      category: $enumDecode(_$NotificationCategoryEnumMap, json['category']),
      title: json['title'] as String,
      body: json['body'] as String,
      collapseKey: json['collapseKey'] as String?,
      data: (json['data'] as Map?)?.map(
        (k, e) => MapEntry(k as String, e as String),
      ),
    );

Map<String, dynamic> _$SendNotificationPayloadToJson(
  _SendNotificationPayload instance,
) => <String, dynamic>{
  'category': _$NotificationCategoryEnumMap[instance.category]!,
  'title': instance.title,
  'body': instance.body,
  'collapseKey': instance.collapseKey,
  'data': instance.data,
};

const _$NotificationCategoryEnumMap = {
  NotificationCategory.aiInteraction: 'ai_interaction',
  NotificationCategory.sessionMessage: 'session_message',
  NotificationCategory.connectionStatus: 'connection_status',
  NotificationCategory.systemUpdate: 'system_update',
};
