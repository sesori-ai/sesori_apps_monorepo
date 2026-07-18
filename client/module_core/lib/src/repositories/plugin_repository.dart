import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/plugin_api.dart";

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
