import "package:freezed_annotation/freezed_annotation.dart";

part "local_notification_payload.freezed.dart";
part "local_notification_payload.g.dart";

/// Typed payload shared by product-shell local-notification adapters.
@Freezed(fromJson: true, toJson: true)
sealed class LocalNotificationPayload with _$LocalNotificationPayload {
  const factory({
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  }) = _LocalNotificationPayload;

  factory fromJson(Map<String, dynamic> json) => _$LocalNotificationPayloadFromJson(json);
}
