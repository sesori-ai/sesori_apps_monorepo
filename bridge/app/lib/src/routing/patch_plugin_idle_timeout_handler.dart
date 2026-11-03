import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class PatchPluginIdleTimeoutHandler({required final PluginLifecycleService _lifecycleService})
    extends BodyRequestHandler<PluginIdleTimeoutUpdateRequest, PluginManagementResponse> {
  this
    : super(
        method: HttpMethod.patch,
        path: "/plugin/idle-timeout",
        fromJson: PluginIdleTimeoutUpdateRequest.fromJson,
      );

  @override
  Future<PluginManagementResponse> handle({
    required RelayRequest request,
    required PluginIdleTimeoutUpdateRequest body,
  }) async {
    try {
      return await _lifecycleService.updateIdleTimeout(request: body);
    } on PluginManagementPluginNotFoundException {
      throw buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on PluginManagementConflictException catch (error) {
      throw buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on PluginManagementMutationOutcomeUncertainException {
      throw buildErrorResponse(request: request, status: 503, message: "plugin mutation outcome is uncertain");
    }
  }
}
