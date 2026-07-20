import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class PluginApi {
  final RelayHttpApiClient _client;

  PluginApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<PluginListResponse>> listPlugins() {
    return _client.get("/plugin", fromJson: PluginListResponse.fromJson);
  }
}
