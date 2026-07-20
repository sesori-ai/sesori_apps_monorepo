import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class GetPluginsHandler extends GetRequestHandler<PluginListResponse> {
  GetPluginsHandler({required PluginLifecycleService lifecycleService})
    : _lifecycleService = lifecycleService,
      super("/plugin");

  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginListResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return PluginListResponse(plugins: _lifecycleService.metadataSnapshot);
  }
}
