import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class PatchPluginIdleTimeoutHandler
    extends BodyRequestHandler<PluginIdleTimeoutUpdateRequest, PluginManagementResponse> {
  PatchPluginIdleTimeoutHandler({
    required PluginLifecycleService lifecycleService,
    required BridgeIdProvider bridgeIdProvider,
  }) : _lifecycleService = lifecycleService,
       _bridgeIdProvider = bridgeIdProvider,
       super(
         HttpMethod.patch,
         "/plugin/idle-timeout",
         fromJson: PluginIdleTimeoutUpdateRequest.fromJson,
       );

  final PluginLifecycleService _lifecycleService;
  final BridgeIdProvider _bridgeIdProvider;

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required PluginIdleTimeoutUpdateRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final response = await _lifecycleService.updateIdleTimeout(request: body);
      return response.copyWith(bridgeId: _bridgeIdProvider.bridgeId);
    } on PluginManagementPluginNotFoundException {
      throw buildErrorResponse(request, 404, "plugin not found");
    }
  }
}
