import "package:freezed_annotation/freezed_annotation.dart";

import "../../../sesori_shared.dart";

part "send_notification_payload.freezed.dart";

part "send_notification_payload.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SendNotificationPayload with _$SendNotificationPayload {
  const factory({
    required NotificationCategory category,
    required String title,
    required String body,
    required String? collapseKey,
    required NotificationData? data,
  }) = _SendNotificationPayload;

  factory fromJson(Map<String, dynamic> json) => _$SendNotificationPayloadFromJson(json);
}
