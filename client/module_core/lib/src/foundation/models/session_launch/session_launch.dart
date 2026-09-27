import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../composer/new_session_submission_snapshot.dart";

part "session_launch.freezed.dart";

/// A new session the user has sent, from Send until nothing is owed for it.
///
/// Sealed rather than one class with a nullable session, so a launch that
/// already has its session can never also look pending, and a launch whose
/// first message was consumed can never still look claimable.
@Freezed()
sealed class SessionLaunch with _$SessionLaunch {
  /// The bridge has not answered yet. [submission] is null once the composing
  /// route has released it (Back mid-create): that absence is what decides
  /// which of the two failure outcomes a failure publishes.
  const factory pending({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required NewSessionSubmissionSnapshot? submission,
  }) = PendingSessionLaunch;

  /// The bridge answered with [session]; the first message waits for the
  /// session screen to take it over.
  const factory created({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required Session session,
    required NewSessionSubmissionSnapshot submission,
  }) = CreatedSessionLaunch;

  /// The handoff was taken or released; the launch is retained only while it
  /// still owes something else. It has no submission at all.
  const factory reconciling({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required Set<String> followUpIds,
    required Session session,
  }) = ReconcilingSessionLaunch;
}
