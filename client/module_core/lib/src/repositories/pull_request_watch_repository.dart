import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../api/pull_request_watch_api.dart";
import "models/pull_request_watch_list_result.dart";

/// The pull requests the current computer's PR monitor watches, for every
/// session, merged ones included until the bridge's local midnight. The list
/// is empty while the PR monitor is off.
@lazySingleton
class PullRequestWatchRepository({required final PullRequestWatchApi _api}) {
  Future<PullRequestWatchListResult> listWatches() async => switch (await _api.listWatches()) {
    SuccessResponse(:final data) => PullRequestWatchListSuccess(watches: data.watches),
    // An older bridge answers the route with its router's bare 404.
    ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PullRequestWatchListBridgeOutdated(),
    ErrorResponse(:final error) => PullRequestWatchListFailure(error: error),
  };
}
