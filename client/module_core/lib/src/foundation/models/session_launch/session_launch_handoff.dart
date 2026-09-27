import "package:freezed_annotation/freezed_annotation.dart";

import "../composer/new_session_submission_snapshot.dart";

part "session_launch_handoff.freezed.dart";

/// What the session screen continues from the composing surface: the first
/// message's sending bubble, until the transcript shows what replaces it.
@Freezed()
sealed class SessionLaunchHandoff with _$SessionLaunchHandoff {
  const factory({
    required NewSessionSubmissionSnapshot submission,

    /// The harness the bubble names once the send runs long.
    required String pluginId,

    /// When Send committed, so the bubble's slow-send copy continues rather
    /// than restarting on each widget the handoff passes through.
    required DateTime startedAt,

    /// Every promptId the launch minted for a follow-up. A bridge-queued prompt
    /// with one of these ids is not the first message's replacement.
    required Set<String> followUpIds,
  }) = _SessionLaunchHandoff;
}
