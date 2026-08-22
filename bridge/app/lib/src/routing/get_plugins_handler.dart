import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class GetPluginsHandler({
  required final PluginLifecycleService _lifecycleService,
  required final BridgeIdProvider _bridgeIdProvider,
}) extends GetRequestHandler<PluginListResponse> {
  this : super("/plugin");

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
      supportsSessionOptions: true,
    );
  }
}
