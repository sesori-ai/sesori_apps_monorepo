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
    if (response case SuccessResponse(:final data)) {
      // TEMPORARY RELEASE GATE (2026-07-24): expose only OpenCode to every
      // client, including clients connected to an older multi-plugin bridge.
      // Revert this gate immediately after the next synchronized release.
      PluginMetadata? openCode;
      for (final plugin in data.plugins) {
        if (plugin.id == legacyMissingPluginId) {
          openCode = plugin.copyWith(isDefault: true);
          break;
        }
      }
      return ApiResponse.success(
        PluginListResponse(plugins: [?openCode]),
      );
    }
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
