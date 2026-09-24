import "package:freezed_annotation/freezed_annotation.dart";

part "session_auto_continuation.freezed.dart";
part "session_auto_continuation.g.dart";

enum AutoContinuationAvailability() { conditional, unavailable, unknown }

enum AutoContinuationPauseReason() { busy, retrying, queued, awaitingInput, unavailable, historyUnavailable, unknown }

enum AutoContinuationFailureReason() { submissionRejected, unknown }

/// Bridge-owned preference and outcome; clients never schedule from this view.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionAutoContinuationView with _$SessionAutoContinuationView {
  const factory({
    required bool enabled,
    @JsonKey(unknownEnumValue: AutoContinuationAvailability.unknown) required AutoContinuationAvailability availability,
    required SessionAutoContinuationStatus status,
  }) = _SessionAutoContinuationView;

  factory fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationViewFromJson(json);
}

/// Times are UTC Unix milliseconds. A known reset may be shown while disabled;
/// only an enabled, available preference can imply a scheduled continuation.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, copyWith: false)
sealed class SessionAutoContinuationStatus with _$SessionAutoContinuationStatus {
  const factory idle() = SessionAutoContinuationIdle;
  const factory resetKnown({required int resetAt, required int continueAt}) = SessionAutoContinuationResetKnown;
  const factory resetUnknown() = SessionAutoContinuationResetUnknown;
  const factory paused({
    required int resetAt,
    required int continueAt,
    @JsonKey(unknownEnumValue: AutoContinuationPauseReason.unknown) required AutoContinuationPauseReason reason,
  }) = SessionAutoContinuationPaused;
  const factory attemptUnconfirmed() = SessionAutoContinuationAttemptUnconfirmed;
  const factory submitted({required int acceptedAt}) = SessionAutoContinuationSubmitted;
  const factory submissionFailed({
    @JsonKey(unknownEnumValue: AutoContinuationFailureReason.unknown) required AutoContinuationFailureReason reason,
  }) = SessionAutoContinuationSubmissionFailed;
  const factory unknown() = SessionAutoContinuationUnknown;

  factory fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationStatusFromJson(json);
}
