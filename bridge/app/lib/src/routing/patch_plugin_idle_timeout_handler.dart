import "dart:convert";

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
    } on PluginManagementConflictException catch (error) {
      throw RelayResponse(
        id: request.id,
        status: 409,
        headers: const {"content-type": "application/json"},
        body: jsonEncode(error.conflict.toJson()),
      );
    } on PluginManagementMutationOutcomeUncertainException {
      throw buildErrorResponse(request, 503, "plugin mutation outcome is uncertain");
    }
  }
}
