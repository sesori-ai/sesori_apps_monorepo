import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_attempt.freezed.dart';
part 'update_attempt.g.dart';

/// Lifecycle status of a persisted [UpdateAttempt].
enum UpdateAttemptStatus() {
  /// The apply is in progress (binary/lib swap underway). A record left in
  /// this state across a restart means the process died mid-apply.
  inFlight,

  /// The swap completed on disk; the new version takes effect on next launch.
  appliedPendingActivation,

  /// The attempt gave up. [UpdateAttempt.reason] carries the cause.
  failed,
}

/// Durable, structured record of a single in-place update attempt.
///
/// Persisted to `installRoot/.sesori-bridge-update-attempt.json` so the next
/// launch can reconcile what happened: confirm a pending activation, recover
/// from a crash mid-apply, or surface a prior failure. Mirrors the JSON cache
/// pattern used by [CachedRelease]/`UpdateCacheApi`.
@Freezed(fromJson: true, toJson: true)
sealed class UpdateAttempt with _$UpdateAttempt {
  const factory({
    /// The version the bridge was running when the attempt started.
    required String fromVersion,

    /// The version the attempt is moving to.
    required String toVersion,

    /// When the attempt began.
    required DateTime startedAt,

    /// The attempt's current lifecycle status.
    required UpdateAttemptStatus status,

    /// Human-readable cause when [status] is [UpdateAttemptStatus.failed], else
    /// `null`.
    required String? reason,
  }) = _UpdateAttempt;

  factory fromJson(Map<String, dynamic> json) => _$UpdateAttemptFromJson(json);
}
