import "package:sesori_shared/sesori_shared.dart";

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
  /// How many watched pull requests need the user: the red count.
  int get needsYouCount => watches.where((item) => item.watch.status is PullRequestWatchStatusNeedsYou).length;
}

final class const PullRequestWatchListFailed() extends PullRequestWatchListState;

/// The computer's bridge predates the PR monitor.
final class const PullRequestWatchListUnsupported() extends PullRequestWatchListState;
