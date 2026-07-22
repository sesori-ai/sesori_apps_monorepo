import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class GetPluginsHandler extends GetRequestHandler<PluginListResponse> {
  GetPluginsHandler({required BridgeIdProvider bridgeIdProvider, required PluginLifecycleService lifecycleService})
    : _bridgeIdProvider = bridgeIdProvider,
      _lifecycleService = lifecycleService,
      super("/plugin");

  final BridgeIdProvider _bridgeIdProvider;
  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginListResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return PluginListResponse(
      bridgeId: _bridgeIdProvider.bridgeId,
      plugins: _lifecycleService.selectableMetadataSnapshot,
    );
  }
}
