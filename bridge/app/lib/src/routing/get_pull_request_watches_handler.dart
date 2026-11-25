import "package:sesori_shared/sesori_shared.dart";

import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `GET /pull-request-watches`: every PR this bridge watches, for
/// any session, merged ones included until local midnight.
class GetPullRequestWatchesHandler({required final SessionViewService _sessionViews})
    extends GetRequestHandler<PullRequestWatchListResponse> {
  this : super(path: "/pull-request-watches");

  @override
  Future<PullRequestWatchListResponse> handle({required RelayRequest request}) => _sessionViews.pullRequestWatches();
}
