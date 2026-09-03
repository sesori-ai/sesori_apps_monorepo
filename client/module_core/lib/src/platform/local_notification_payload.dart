import "package:freezed_annotation/freezed_annotation.dart";

part "local_notification_payload.freezed.dart";
part "local_notification_payload.g.dart";

/// Typed payload shared by product-shell local-notification adapters.
///
/// Desktop sets [accountId] to reject an OS-delivered open after account
/// replacement. Mobile leaves it null because push-open ownership is handled by
/// its existing authenticated registration lifecycle.
@Freezed(fromJson: true, toJson: true)
sealed class LocalNotificationPayload with _$LocalNotificationPayload {
  const factory({
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
    required String? accountId,
  }) = _LocalNotificationPayload;

  factory fromJson(Map<String, dynamic> json) => _$LocalNotificationPayloadFromJson(json);
}
