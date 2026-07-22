import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class PatchPluginIdleTimeoutHandler
    extends BodyRequestHandler<PluginIdleTimeoutUpdateRequest, PluginManagementResponse> {
  PatchPluginIdleTimeoutHandler({required PluginLifecycleService lifecycleService})
    : _lifecycleService = lifecycleService,
      super(
        HttpMethod.patch,
        "/plugin/idle-timeout",
        fromJson: PluginIdleTimeoutUpdateRequest.fromJson,
      );

  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required PluginIdleTimeoutUpdateRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      return await _lifecycleService.updateIdleTimeout(request: body);
    } on PluginManagementPluginNotFoundException {
      throw buildErrorResponse(request, 404, "plugin not found");
    } on PluginManagementBadRequestException catch (error) {
      throw buildErrorResponse(request, 400, error.message);
    }
  }
}
