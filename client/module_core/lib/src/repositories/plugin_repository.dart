import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/plugin_api.dart";
import "models/plugin_management_result.dart";

@lazySingleton
class PluginRepository {
  final PluginApi _api;

  PluginRepository({required PluginApi api}) : _api = api;

  Future<PluginManagementLoadResult> getManagement() async {
    return switch (await _api.getManagement()) {
      SuccessResponse(:final data) => PluginManagementLoadResult.supported(response: data, refreshError: null),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PluginManagementLoadResult.unsupported(),
      ErrorResponse(:final error) => PluginManagementLoadResult.failure(error: error),
    };
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    return _mapMutation(future: _api.command(pluginId: pluginId, request: request));
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) {
    return _mapMutation(future: _api.updateIdleTimeout(request: request));
  }

  Future<PluginManagementMutationResult> _mapMutation({
    required Future<ApiResponse<PluginManagementResponse>> future,
  }) async {
    return switch (await future) {
      SuccessResponse(:final data) => PluginManagementMutationResult.success(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PluginManagementMutationResult.notFound(),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 409, rawErrorString: final body)) =>
        _mapConflict(body: body),
      // A sent mutation whose 2xx outcome cannot be proven may have committed;
      // never surface it as a retryable ordinary failure.
      ErrorResponse(error: JsonParsingError() || EmptyResponseError()) =>
        const PluginManagementMutationResult.uncertain(),
      ErrorResponse(:final error) => PluginManagementMutationResult.failure(error: error),
    };
  }

  PluginManagementMutationResult _mapConflict({required String? body}) {
    if (body != null) {
      try {
        return PluginManagementMutationResult.conflict(
          conflict: PluginLifecycleConflict.fromJson(jsonDecodeMap(body)),
        );
      } on Object {
        // The typed failure below is the single observable outcome.
      }
    }
    return PluginManagementMutationResult.failure(
      error: ApiError.nonSuccessCode(errorCode: 409, rawErrorString: body),
    );
  }

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
}
