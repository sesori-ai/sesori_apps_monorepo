import "package:freezed_annotation/freezed_annotation.dart";

import "notification_category.dart";

part "send_notification_payload.freezed.dart";

part "send_notification_payload.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SendNotificationPayload with _$SendNotificationPayload {
  const factory SendNotificationPayload({
    required NotificationCategory category,
    required String title,
    required String body,
    String? collapseKey,
    Map<String, String>? data,
  }) = _SendNotificationPayload;

  factory SendNotificationPayload.fromJson(Map<String, dynamic> json) => _$SendNotificationPayloadFromJson(json);
}
