import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class GetPluginSetupHandler extends GetRequestHandler<PluginSetupResponse> {
  GetPluginSetupHandler({required PluginLifecycleService lifecycleService})
    : _lifecycleService = lifecycleService,
      super("/plugin/setup");

  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginSetupResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _lifecycleService.setupSnapshot;
  }
}
