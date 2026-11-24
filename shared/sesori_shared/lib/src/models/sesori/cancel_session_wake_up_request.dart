import "package:freezed_annotation/freezed_annotation.dart";

part "cancel_session_wake_up_request.freezed.dart";
part "cancel_session_wake_up_request.g.dart";

/// Request body for `POST /session/wake-up/cancel`, which answers with the
/// updated session. A wake-up that already fired or was cancelled needs
/// nothing more, so it answers the same way.
@Freezed(fromJson: true, toJson: true)
sealed class CancelSessionWakeUpRequest with _$CancelSessionWakeUpRequest {
  const factory({
    /// The root session the wake-up belongs to.
    required String sessionId,
    required String wakeUpId,
  }) = _CancelSessionWakeUpRequest;

  factory fromJson(Map<String, dynamic> json) => _$CancelSessionWakeUpRequestFromJson(json);
}
