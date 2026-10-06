import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../errors/remote_failure_reason.dart";
import "../composer/queued_session_submission.dart";

part "session_launch_outcome.freezed.dart";

/// How a launch's creation ended. The failure is split by whether a composer
/// is still attached, so exactly one reader acts on each outcome.
@Freezed()
sealed class SessionLaunchOutcome with _$SessionLaunchOutcome {
  const factory succeeded({required String launchId, required Session session}) = SessionLaunchSucceeded;

  /// The composing route still holds the payload and restores it, with the
  /// [followUps] sent after it, none of which could be sent without a session.
  const factory failedWhileComposing({
    required String launchId,
    required RemoteFailureReason reason,
    required List<QueuedSessionSubmission> followUps,
  }) = SessionLaunchFailedWhileComposing;

  /// The composing route released the payload, so no composer can restore it.
  const factory failedAfterLeaving({
    required String launchId,
    required String projectId,
    required RemoteFailureReason reason,
  }) = SessionLaunchFailedAfterLeaving;
}
