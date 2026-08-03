// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPreferencesApiRecord _$NotificationPreferencesApiRecordFromJson(
  Map json,
) => _NotificationPreferencesApiRecord(
  deviceId: json['deviceId'] as String,
  notifications: NotificationPreferencesApiNotifications.fromJson(
    Map<String, dynamic>.from(json['notifications'] as Map),
  ),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

_NotificationPreferencesApiNotifications
_$NotificationPreferencesApiNotificationsFromJson(Map json) =>
    _NotificationPreferencesApiNotifications(
      aiInteraction: json['aiInteraction'] as bool,
      sessionMessage: json['sessionMessage'] as bool,
      connectionStatus: json['connectionStatus'] as bool,
      systemUpdate: json['systemUpdate'] as bool,
    );
