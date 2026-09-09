import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class PluginApi({required final RelayHttpApiClient _client}) {
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

  Future<ApiResponse<PluginAuthenticationChallengeResponse>> startAuthentication({required String pluginId}) {
    return _client.post(
      "/plugin/${Uri.encodeComponent(pluginId)}/authentication",
      body: const SuccessEmptyResponse().toJson(),
      fromJson: PluginAuthenticationChallengeResponse.fromJson,
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> submitAuthenticationRedirect({
    required String pluginId,
    required PluginAuthenticationRedirectRequest request,
  }) {
    return _client.post(
      "/plugin/${Uri.encodeComponent(pluginId)}/authentication/redirect",
      body: request.toJson(),
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> cancelAuthentication({required String pluginId}) {
    return _client.delete(
      "/plugin/${Uri.encodeComponent(pluginId)}/authentication",
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> startCatalogImport({required String pluginId}) {
    return _client.post(
      "/plugin/import",
      body: CatalogImportRequest(pluginId: pluginId).toJson(),
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  /// Cancels the import for one plugin. The route cancels exactly one plugin
  /// per call, so a caller cancelling several issues one request each.
  Future<ApiResponse<SuccessEmptyResponse>> cancelCatalogImport({required String pluginId}) {
    return _client.delete(
      "/plugin/import",
      body: CatalogImportRequest(pluginId: pluginId).toJson(),
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  Future<ApiResponse<CatalogImportStatusesResponse>> getCatalogImportStatuses() {
    return _client.get("/plugin/import", fromJson: CatalogImportStatusesResponse.fromJson);
  }
}
