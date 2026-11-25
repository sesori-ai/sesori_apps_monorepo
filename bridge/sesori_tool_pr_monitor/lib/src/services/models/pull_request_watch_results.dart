import "../../models/gh_cli_exception.dart";
import "../../models/pull_request_target.dart";
import "../../repositories/models/pull_request_snapshot.dart";

/// How a request to watch a PR ended.
sealed class const PullRequestWatchStart();

final class const PullRequestWatchStarted({
  required final String title,

  /// The first report, where every existing comment counts as new.
  required final String report,
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
});
