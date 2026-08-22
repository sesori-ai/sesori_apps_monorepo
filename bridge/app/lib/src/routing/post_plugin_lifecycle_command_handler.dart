import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class PostPluginLifecycleCommandHandler({required final PluginLifecycleService _lifecycleService})
    extends BodyRequestHandler<PluginLifecycleCommandRequest, PluginManagementResponse> {
  this
    : super(
        HttpMethod.post,
        "/plugin/:id/command",
        fromJson: PluginLifecycleCommandRequest.fromJson,
      );

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required PluginLifecycleCommandRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final pluginId = pathParams["id"];
      if (pluginId == null) throw buildErrorResponse(request, 400, "plugin id is required");
      return await _lifecycleService.command(pluginId: pluginId, request: body);
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
    } on PluginManagementCommandFailedException {
      throw buildErrorResponse(request, 500, "plugin command failed");
    }
  }
}
