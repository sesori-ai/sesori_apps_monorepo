import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class PostPluginAuthenticationHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(HttpMethod.post, "/plugin/:id/authentication");

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final pluginId = pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request, 400, "plugin id is required");
      return buildOkJsonResponse(request, await _lifecycleService.authenticate(pluginId: pluginId));
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request, 404, "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return RelayResponse(
        id: request.id,
        status: 409,
        headers: const {"content-type": "application/json"},
        body: jsonEncode(error.conflict.toJson()),
      );
    } on PluginAuthenticationChallengeUnavailableException {
      return buildErrorResponse(request, 500, "plugin authentication did not provide a challenge");
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication failed", error, stackTrace);
      return buildErrorResponse(request, 500, "plugin authentication failed");
    }
  }
}

class DeletePluginAuthenticationHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(HttpMethod.delete, "/plugin/:id/authentication");

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final pluginId = pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request, 400, "plugin id is required");
      return buildOkJsonResponse(request, await _lifecycleService.cancelAuthentication(pluginId: pluginId));
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request, 404, "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return RelayResponse(
        id: request.id,
        status: 409,
        headers: const {"content-type": "application/json"},
        body: jsonEncode(error.conflict.toJson()),
      );
    } on Object catch (error, stackTrace) {
      Log.w("DELETE ${request.path}: plugin authentication cancellation failed", error, stackTrace);
      return buildErrorResponse(request, 500, "plugin authentication cancellation failed");
    }
  }
}
