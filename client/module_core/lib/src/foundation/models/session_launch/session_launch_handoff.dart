import "package:freezed_annotation/freezed_annotation.dart";

import "../composer/new_session_submission_snapshot.dart";
import "../composer/queued_session_submission.dart";

part "session_launch_handoff.freezed.dart";

/// What the session screen continues from the composing surface: the first
/// message's sending bubble, until the transcript shows what replaces it, and
/// the follow-ups the bridge accepted before the screen took over.
@Freezed()
sealed class SessionLaunchHandoff with _$SessionLaunchHandoff {
  const factory({
    required NewSessionSubmissionSnapshot submission,

    /// The harness the bubble names once the send runs long.
    required String pluginId,

    /// When Send committed, so the bubble's slow-send copy continues rather
    /// than restarting on each widget the handoff passes through.
    required DateTime startedAt,

    /// Every promptId that is not the first message: those the launch minted
    /// for a follow-up, and those the session screen minted since. A
    /// bridge-queued prompt with one of these ids is not the first message's
    /// replacement.
    required Set<String> followUpIds,

    /// Follow-ups the bridge accepted before the handoff was taken, oldest
    /// first. The taker parks them so their bubbles never blank.
    required List<QueuedSessionSubmission> acceptedFollowUps,
  }) = _SessionLaunchHandoff;
}
