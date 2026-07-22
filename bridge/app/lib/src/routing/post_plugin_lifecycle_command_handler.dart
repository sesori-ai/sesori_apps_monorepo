import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/plugin_lifecycle_service.dart";

class PostPluginLifecycleCommandHandler
    extends BodyRequestHandler<PluginLifecycleCommandRequest, PluginManagementResponse> {
  PostPluginLifecycleCommandHandler({required PluginLifecycleService lifecycleService})
    : _lifecycleService = lifecycleService,
      super(
        HttpMethod.post,
        "/plugin/:id/command",
        fromJson: PluginLifecycleCommandRequest.fromJson,
      );

  final PluginLifecycleService _lifecycleService;

  @override
  Future<PluginManagementResponse> handle(
    RelayRequest request, {
    required PluginLifecycleCommandRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      return await _lifecycleService.command(pluginId: pathParams["id"]!, request: body);
    } on PluginManagementPluginNotFoundException {
      throw buildErrorResponse(request, 404, "plugin not found");
    } on PluginManagementConflictException catch (error) {
      throw RelayResponse(
        id: request.id,
        status: 409,
        headers: const {"content-type": "application/json"},
        body: jsonEncode(error.conflict.toJson()),
      );
    }
  }
}
