import "package:freezed_annotation/freezed_annotation.dart";

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
    required String? reportedError,

    /// The automatic merge attempt's result, for the next report only.
    required String? autoMergeNotice,

    /// Turning auto-merge on removed the label from an eligible PR. Until new
    /// activity, readiness waits for the agent's own judgment.
    required bool resetPending,

    /// The ready label was just withdrawn: the report saying so goes first,
    /// and only a later quiet report may add it back.
    required bool restoreAfterReport,
  }) = _PullRequestMergeState;

  static const PullRequestMergeState initial = PullRequestMergeState(
    retry: null,
    reportedError: null,
    autoMergeNotice: null,
    resetPending: false,
    restoreAfterReport: false,
  );
}

/// [ready] is the label state a failed change wanted, [baseline] the PR as
/// it was at the first failure, and [error] the report text.
@freezed
sealed class PullRequestReadinessRetry with _$PullRequestReadinessRetry {
  const factory({
    required bool ready,
    required PullRequestSnapshot baseline,
    required String error,
  }) = _PullRequestReadinessRetry;
}

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
