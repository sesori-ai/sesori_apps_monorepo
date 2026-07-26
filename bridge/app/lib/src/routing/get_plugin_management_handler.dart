import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class GetPluginManagementHandler extends GetRequestHandler<PluginManagementResponse> {
  GetPluginManagementHandler({required PluginLifecycleService lifecycleService, required BridgeIdProvider bridgeIdProvider})
    : _lifecycleService = lifecycleService,
      _bridgeIdProvider = bridgeIdProvider,
      super("/plugin/management");

  final PluginLifecycleService _lifecycleService;
  final BridgeIdProvider _bridgeIdProvider;

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async => _lifecycleService.managementSnapshot.copyWith(bridgeId: _bridgeIdProvider.bridgeId);
}
