import "../../models/gh_cli_exception.dart";
import "../../models/pull_request_target.dart";
import "../../repositories/models/pull_request_monitor_config.dart";
import "../../repositories/models/pull_request_snapshot.dart";
import "pull_request_config_change.dart";
import "pull_request_merge_state.dart";

/// How a request to watch a PR ended.
sealed class const PullRequestWatchStart();

final class const PullRequestWatchStarted({
  required final String title,

  /// The first report, where every existing comment counts as new.
  required final String report,

  /// Whether auto-merge applies to the PR, from this watch or another.
  required final bool autoMerge,

  /// Turning auto-merge on removed a ready label the PR already carried.
  required final bool readyLabelRemoved,
}) extends PullRequestWatchStart;

final class const PullRequestAlreadyWatched({required final PullRequestWatchStatus status})
    extends PullRequestWatchStart;

/// `gh` could not say which account it is signed in as.
final class const PullRequestIdentityFailed({required final GhCliException error}) extends PullRequestWatchStart;

/// The PR could not be fetched. [error] is a `GhCliException` or a
/// `PullRequestPaginationException`, whose text is actionable.
final class const PullRequestFetchFailed({required final Exception error}) extends PullRequestWatchStart;

/// The PR is already merged or closed, so there is nothing to watch.
final class const PullRequestAlreadyEnded({required final PullRequestState state}) extends PullRequestWatchStart;

/// Auto-merge was asked for, but the ready label the PR carried could not be
/// removed, so no watch started.
final class const PullRequestReadyResetFailed({required final Exception error}) extends PullRequestWatchStart;

/// How a request for a watched PR's report ended.
sealed class const PullRequestReportResult();

final class const PullRequestReportFresh({required final String report}) extends PullRequestReportResult;

/// The refresh failed, so [report] renders the last successful poll and
/// nothing was marked as reported.
final class const PullRequestReportStale({required final String report, required final Exception error})
    extends PullRequestReportResult;

/// The refresh failed and no poll has succeeded since the bridge started.
final class const PullRequestReportUnavailable({required final Exception error}) extends PullRequestReportResult;

final class const PullRequestNotWatched() extends PullRequestReportResult;

/// One watch as `pr_watch_status` shows it.
final class const PullRequestWatchStatus({
  required final PullRequestTarget target,

  /// A report is due but waits for running CI.
  required final bool ciHold,

  /// Activity is waiting for its report.
  required final bool activityBuffered,
  required final Duration sinceLastReport,
  required final int consecutiveFailures,

  /// Whether the PR carries the ready label; null before the first poll
  /// after a restart.
  required final bool? ready,
  required final bool autoMerge,
});

final class const PullRequestWatchStatuses({
  required final List<PullRequestWatchStatus> watches,

  /// Every PR this bridge polls, for any session.
  required final int watchedPullRequests,
  required final PullRequestMonitorConfig config,
});

/// What `mark_pr_ready` or `unmark_pr_ready` changed.
sealed class const PullRequestReadyChange();

/// [mergeAttempt] is the merge it made, when auto-merge is on.
final class const PullRequestMarkedReady({required final PullRequestMergeAttempt? mergeAttempt})
    extends PullRequestReadyChange;

final class const PullRequestUnmarkedReady({required final bool wasCarried}) extends PullRequestReadyChange;

/// How `set_pr_auto_merge` ended.
sealed class const PullRequestAutoMergeResult();

final class const PullRequestAutoMergeNotWatched() extends PullRequestAutoMergeResult;

final class const PullRequestAutoMergeUnchanged({required final bool enabled}) extends PullRequestAutoMergeResult;

final class const PullRequestAutoMergeSet({
  required final bool enabled,

  /// Whether auto-merge now applies to the PR, from this watch or another.
  required final bool effective,

  /// Turning auto-merge on removed a ready label the PR already carried.
  required final bool readyLabelRemoved,
}) extends PullRequestAutoMergeResult;

/// How `configure_pr_monitor` ended. Each [config] is the settings now in
/// effect.
sealed class const PullRequestConfigureResult();

final class const PullRequestConfigApplied({required final PullRequestMonitorConfig config})
    extends PullRequestConfigureResult;

/// [autoMerge] waits for the user's Allow; the rest of the change applied.
final class const PullRequestConfigAwaitingApproval({
  required final PullRequestMonitorConfig config,
  required final PullRequestAutoMergeDefaultChange autoMerge,
}) extends PullRequestConfigureResult;

/// The Allow request for [autoMerge] could not be shown, so it did not
/// apply; the rest of the change did.
final class const PullRequestConfigApprovalDropped({
  required final PullRequestMonitorConfig config,
  required final PullRequestAutoMergeDefaultChange autoMerge,
}) extends PullRequestConfigureResult;
