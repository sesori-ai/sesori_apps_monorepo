import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/plugin_api.dart";
import "models/plugin_management_result.dart";

@lazySingleton
class PluginRepository {
  final PluginApi _api;

  PluginRepository({required PluginApi api}) : _api = api;

  Future<ApiResponse<PluginListResponse>> listPlugins() async {
    final response = await _api.listPlugins();
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 404))) {
      // COMPATIBILITY 2026-07-18 (v1.6.0): Bridges without plugin discovery return 404 and can only target OpenCode. Remove this fallback once those bridges are unsupported.
      return ApiResponse.success(
        const PluginListResponse(
          bridgeId: null,
          plugins: [
            PluginMetadata(
              id: legacyMissingPluginId,
              displayName: "OpenCode",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      );
    }
    return response;
  }

  Future<PluginManagementLoadResult> getManagement() async {
    final response = await _api.getManagement();
    return switch (response) {
      SuccessResponse(:final data) => PluginManagementLoadResult.supported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PluginManagementLoadResult.unsupported(),
      ErrorResponse(:final error) => PluginManagementLoadResult.failure(error: error),
    };
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    final response = await _api.command(pluginId: pluginId, request: request);
    return _mapMutation(response);
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  }) async {
    final response = await _api.updateIdleTimeout(request: request);
    return _mapMutation(response);
  }

  PluginManagementMutationResult _mapMutation(ApiResponse<PluginManagementResponse> response) {
    switch (response) {
      case SuccessResponse(:final data):
        return PluginManagementMutationResult.success(response: data);
      case ErrorResponse(:final error):
        if (error case NonSuccessCodeError(errorCode: 404)) {
          return const PluginManagementMutationResult.notFound();
        }
        if (error case NonSuccessCodeError(errorCode: 409, :final rawErrorString)) {
          return _parseConflict(rawErrorString) ?? PluginManagementMutationResult.failure(error: error);
        }
        return PluginManagementMutationResult.failure(error: error);
    }
  }

  PluginManagementMutationResult? _parseConflict(String? rawBody) {
    if (rawBody == null) return null;
    try {
      return PluginManagementMutationResult.conflict(
        conflict: PluginLifecycleConflict.fromJson(jsonDecodeMap(rawBody)),
      );
    } on Object {
      // Keep malformed 409 responses as their original explicit API failure.
      return null;
    }
  }
}
