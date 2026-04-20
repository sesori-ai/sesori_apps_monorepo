import "package:freezed_annotation/freezed_annotation.dart";

part "notification_tap_event.freezed.dart";

part "notification_tap_event.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class NotificationTapEvent with _$NotificationTapEvent {
  const factory NotificationTapEvent({
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  }) = _NotificationTapEvent;

  factory NotificationTapEvent.fromJson(Map<String, dynamic> json) => _$NotificationTapEventFromJson(json);
}
