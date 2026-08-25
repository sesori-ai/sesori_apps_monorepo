import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class GetPluginManagementHandler({required final PluginLifecycleService _lifecycleService})
    extends GetRequestHandler<PluginManagementResponse> {
  this : super("/plugin/management");

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request,
  ) async => _lifecycleService.managementSnapshot;
}
