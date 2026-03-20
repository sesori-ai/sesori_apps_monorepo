import "package:freezed_annotation/freezed_annotation.dart";

part "session_status.freezed.dart";

part "session_status.g.dart";

@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SessionStatus with _$SessionStatus {
  @FreezedUnionValue("idle")
  const factory SessionStatus.idle() = SessionStatusIdle;

  @FreezedUnionValue("busy")
  const factory SessionStatus.busy() = SessionStatusBusy;

  @FreezedUnionValue("retry")
  const factory SessionStatus.retry({
    required int attempt,
    required String message,
    required int next,
  }) = SessionStatusRetry;

  factory SessionStatus.fromJson(Map<String, dynamic> json) => _$SessionStatusFromJson(json);
}
