import "package:freezed_annotation/freezed_annotation.dart";

import "../composer/prompt_send_failure.dart";
import "../composer/queued_session_submission.dart";

part "launch_follow_up.freezed.dart";

/// A message the user sent after the first one, before the session existed,
/// and where its delivery stands. Shaped like the session queue's own
/// `LocalSendPhase`, so the session screen renders it the same way.
@Freezed()
sealed class LaunchFollowUp with _$LaunchFollowUp {
  /// Not sent yet; it waits for the session, or for the one ahead of it.
  const factory queued({required QueuedSessionSubmission submission}) = QueuedLaunchFollowUp;

  /// The one being sent now.
  const factory sending({required QueuedSessionSubmission submission}) = SendingLaunchFollowUp;

  /// The bridge accepted it; held only until a session screen parks it.
  const factory accepted({required QueuedSessionSubmission submission}) = AcceptedLaunchFollowUp;

  /// The bridge refused it or the send was lost. The ones behind it wait until
  /// the user retries or removes it.
  const factory failed({
    required QueuedSessionSubmission submission,
    required PromptSendFailure failure,
  }) = FailedLaunchFollowUp;
}
