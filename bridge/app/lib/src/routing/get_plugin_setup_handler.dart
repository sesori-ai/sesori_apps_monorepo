import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class GetPluginSetupHandler({required final PluginLifecycleService _lifecycleService})
    extends GetRequestHandler<PluginSetupResponse> {
  this : super("/plugin/setup");

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
