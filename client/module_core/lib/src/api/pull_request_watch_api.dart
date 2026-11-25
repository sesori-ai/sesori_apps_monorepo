import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

/// The bridge's list of watched pull requests. A bridge that predates the PR
/// monitor answers with its router's bare 404.
@lazySingleton
class PullRequestWatchApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<PullRequestWatchListResponse>> listWatches() =>
      _client.get("/pull-request-watches", fromJson: PullRequestWatchListResponse.fromJson);
}
