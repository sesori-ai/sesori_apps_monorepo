import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// The outcome of listing the current computer's watched pull requests.
sealed class const PullRequestWatchListResult();

final class const PullRequestWatchListSuccess({
  required final List<PullRequestWatchListItem> watches,
}) extends PullRequestWatchListResult;

/// The bridge predates the PR monitor: it has no list route.
final class const PullRequestWatchListBridgeOutdated() extends PullRequestWatchListResult;

final class const PullRequestWatchListFailure({required final ApiError error}) extends PullRequestWatchListResult;
