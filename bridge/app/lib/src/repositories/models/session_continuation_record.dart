import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "session_continuation_record.freezed.dart";
part "session_continuation_record.g.dart";

enum SessionContinuationReadiness() { idle, busy, retrying, queued, awaitingInput, unavailable, unknown }

final class const SessionContinuationRecord({
  required final String sessionId,
  required final bool enabled,
  required final SessionContinuationOutcome outcome,
});

@Freezed(unionKey: "kind", fromJson: true, toJson: true, copyWith: false)
sealed class const SessionContinuationOutcome._() with _$SessionContinuationOutcome {
  const factory none() = SessionContinuationNone;
  const factory resetKnown({
    required String errorMessageId,
    required DateTime observedAt,
    required DateTime resetAt,
  }) = SessionContinuationResetKnown;
  const factory resetUnknown({required String errorMessageId, required DateTime observedAt}) =
      SessionContinuationResetUnknown;
  const factory paused({
    required String errorMessageId,
    required DateTime observedAt,
    required DateTime resetAt,
    required AutoContinuationPauseReason reason,
    required DateTime recheckAt,
  }) = SessionContinuationPaused;
  const factory consumed({
    required String errorMessageId,
    required String promptId,
    required DateTime attemptedAt,
  }) = SessionContinuationConsumed;
  const factory submitted({
    required String errorMessageId,
    required String promptId,
    required DateTime acceptedAt,
  }) = SessionContinuationSubmitted;
  const factory cancelled({required String errorMessageId}) = SessionContinuationCancelled;
  const factory submissionFailed({
    required String errorMessageId,
    required AutoContinuationFailureReason reason,
  }) = SessionContinuationSubmissionFailed;

  factory fromJson(Map<String, dynamic> json) => _$SessionContinuationOutcomeFromJson(json);

  String? get observationId => switch (this) {
    SessionContinuationNone() => null,
    SessionContinuationResetKnown(:final errorMessageId) ||
    SessionContinuationResetUnknown(:final errorMessageId) ||
    SessionContinuationPaused(:final errorMessageId) ||
    SessionContinuationConsumed(:final errorMessageId) ||
    SessionContinuationSubmitted(:final errorMessageId) ||
    SessionContinuationCancelled(:final errorMessageId) ||
    SessionContinuationSubmissionFailed(:final errorMessageId) => errorMessageId,
  };
}
