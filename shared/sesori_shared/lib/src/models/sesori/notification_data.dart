import "package:freezed_annotation/freezed_annotation.dart";

import "notification_category.dart";

part "notification_data.freezed.dart";

part "notification_data.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class NotificationData with _$NotificationData {
  const factory NotificationData({
    required NotificationCategory category,
    String? sessionId,
    String? eventType,
  }) = _NotificationData;

  factory NotificationData.fromJson(Map<String, dynamic> json) => _$NotificationDataFromJson(json);
}
