import "package:freezed_annotation/freezed_annotation.dart";

import "../../repositories/models/pull_request_merge_outcome.dart";
import "../../repositories/models/pull_request_snapshot.dart";

part "pull_request_merge_state.freezed.dart";

/// A watched PR's readiness bookkeeping between polls (spec §6–§7). It lives
/// in memory only: a restart starts again from [initial].
@freezed
sealed class PullRequestMergeState with _$PullRequestMergeState {
  const factory({
    /// The label change that failed, retried on each poll.
    required PullRequestReadinessRetry? retry,

    /// The failure the last report showed; a different one reports at once.
    required PullRequestReadinessRetry? reportedRetry,

    /// The automatic merge attempt, for the next report only.
    required PullRequestMergeAttempt? mergeAttempt,

    /// Turning auto-merge on removed the label from an eligible PR. Until new
    /// activity, readiness waits for the agent's own judgment.
    required bool resetPending,

    /// The ready label was just withdrawn: the report saying so goes first,
    /// and only a later quiet report may add it back.
    required bool restoreAfterReport,
  }) = _PullRequestMergeState;

  static const PullRequestMergeState initial = PullRequestMergeState(
    retry: null,
    reportedRetry: null,
    mergeAttempt: null,
    resetPending: false,
    restoreAfterReport: false,
  );
}

/// [ready] is the label state a failed change wanted, [baseline] the PR as
/// it was at the first failure, and [cause] the latest failure.
final class const PullRequestReadinessRetry({
  required final bool ready,
  required final PullRequestSnapshot baseline,
  required final Exception cause,
}) {
  /// Whether [other] failed the same way, so a report need not repeat it.
  /// Exceptions have no value equality; their type and text identify them.
  bool sameFailureAs({required PullRequestReadinessRetry? other}) =>
      other != null &&
      other.ready == ready &&
      other.cause.runtimeType == cause.runtimeType &&
      other.cause.toString() == cause.toString();
}

/// The one squash merge a ready label allowed, at [headSha].
final class const PullRequestMergeAttempt({
  required final String headSha,
  required final PullRequestMergeOutcome outcome,
});

/// When the PR needs a report because of a readiness change.
enum PullRequestReportNeed() {
  none,

  /// After the quiet window, like any other activity.
  afterQuiet,

  /// In this poll.
  now,
}

/// A readiness step's result: the PR as it now stands (its labels patched to
/// match what the step did), the new state, and the report it calls for.
final class const PullRequestMergeStep({
  required final PullRequestSnapshot snapshot,
  required final PullRequestMergeState state,
  required final PullRequestReportNeed need,
});
