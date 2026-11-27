import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/pull_request_watch_stage.dart";

/// One session's watch of one pull request.
typedef PullRequestWatchKey = ({String sessionId, String repository, int number});

extension PullRequestWatchListItemKey on PullRequestWatchListItem {
  PullRequestWatchKey get key => (sessionId: sessionId, repository: watch.repository, number: watch.number);
}

sealed class const PullRequestWatchListState();

final class const PullRequestWatchListLoading() extends PullRequestWatchListState;

/// The current computer's watched pull requests, in the bridge's order. Each
/// auto-merge shows what the user last set, before the bridge confirms it.
final class const PullRequestWatchListLoaded({
  required final List<PullRequestWatchListItem> watches,

  /// The watches whose Stop is on its way to the bridge.
  required final Set<PullRequestWatchKey> stopping,
}) extends PullRequestWatchListState {
  /// How many watched pull requests wait for the user to merge them: the
  /// muted count.
  int get toMergeCount => watches
      .where((item) => PullRequestWatchStage.of(status: item.watch.status) == PullRequestWatchStage.toMerge)
      .length;
}

final class const PullRequestWatchListFailed() extends PullRequestWatchListState;

/// The computer's bridge predates the PR monitor.
final class const PullRequestWatchListUnsupported() extends PullRequestWatchListState;
