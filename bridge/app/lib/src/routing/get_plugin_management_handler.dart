import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class GetPluginManagementHandler({required PluginLifecycleService lifecycleService}) extends GetRequestHandler<PluginManagementResponse> {
  this
    : _lifecycleService = lifecycleService,
      super("/plugin/management");

  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async => _lifecycleService.managementSnapshot;
}
