import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class PullRequestRefreshSettingsApi {
  PullRequestRefreshSettingsApi({required RelayHttpApiClient client}) : _client = client;

  final RelayHttpApiClient _client;

  Future<ApiResponse<PullRequestRefreshSettingsResponse>> getSettings() {
    return _client.get(
      "/settings/pull-request-refresh",
      fromJson: PullRequestRefreshSettingsResponse.fromJson,
    );
  }
}
