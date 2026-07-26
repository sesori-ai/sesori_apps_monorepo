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

  Future<ApiResponse<PluginManagementResponse>> getManagement() {
    return _client.get("/plugin/management", fromJson: PluginManagementResponse.fromJson);
  }

  Future<ApiResponse<PluginManagementResponse>> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    return _client.post(
      "/plugin/${Uri.encodeComponent(pluginId)}/command",
      body: request.toJson(),
      fromJson: PluginManagementResponse.fromJson,
    );
  }

  Future<ApiResponse<PluginManagementResponse>> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) {
    return _client.patch(
      "/plugin/idle-timeout",
      body: request.toJson(),
      fromJson: PluginManagementResponse.fromJson,
    );
  }
}
