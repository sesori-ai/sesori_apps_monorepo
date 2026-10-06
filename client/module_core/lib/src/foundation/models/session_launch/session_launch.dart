import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../composer/new_session_submission_snapshot.dart";
import "launch_follow_up.dart";

part "session_launch.freezed.dart";

/// A new session the user has sent, from Send until nothing is owed for it.
///
/// Sealed rather than one class with a nullable session, so a launch that
/// already has its session can never also look pending, and a launch whose
/// first message was consumed can never still look claimable.
///
/// Every variant carries [followUps], the messages sent after the first one,
/// in the order they were pressed, and [followUpIds], every promptId the
/// launch ever minted for one. [followUps] shrinks as they are delivered and
/// handed over; [followUpIds] never does.
@Freezed()
sealed class SessionLaunch with _$SessionLaunch {
  /// The bridge has not answered yet and the composing route still holds the
  /// first message.
  const factory pending({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required List<LaunchFollowUp> followUps,
    required NewSessionSubmissionSnapshot submission,
  }) = PendingSessionLaunch;

  /// The bridge has not answered yet and the composing route released the
  /// first message (Back mid-create): no composer can restore it, and the
  /// session, once created, has nothing to hand over.
  const factory pendingReleased({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required List<LaunchFollowUp> followUps,
  }) = ReleasedPendingSessionLaunch;

  /// The bridge answered with [session]; the first message waits for the
  /// session screen to take it over.
  const factory created({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required List<LaunchFollowUp> followUps,
    required Session session,
    required NewSessionSubmissionSnapshot submission,
  }) = CreatedSessionLaunch;

  /// The handoff was taken or released; the launch is retained only while a
  /// follow-up is still owed. It has no submission at all.
  const factory reconciling({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required List<LaunchFollowUp> followUps,
    required Session session,
  }) = ReconcilingSessionLaunch;
}
