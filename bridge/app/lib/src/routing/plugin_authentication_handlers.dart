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
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request, 400, "plugin id is required");
      return buildOkJsonResponse(
        request: request,
        body: await _lifecycleService.authenticate(pluginId: pluginId),
      );
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request, 404, "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on PluginAuthenticationChallengeUnavailableException {
      return buildErrorResponse(request, 500, "plugin authentication did not provide a challenge");
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication failed", error, stackTrace);
      return buildErrorResponse(request, 500, "plugin authentication failed");
    }
  }
}

class PostPluginAuthenticationRedirectHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(HttpMethod.post, "/plugin/:id/authentication/redirect");

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request, 400, "plugin id is required");
      final body = request.body;
      if (body == null) return buildErrorResponse(request, 400, "authentication redirect body is required");
      final PluginAuthenticationRedirectRequest redirectRequest;
      try {
        redirectRequest = PluginAuthenticationRedirectRequest.fromJson(jsonDecodeMap(body));
      } on Object {
        return buildErrorResponse(request, 400, "invalid authentication redirect body");
      }
      final rawUrl = redirectRequest.redirectUrl;
      if (rawUrl.isEmpty || rawUrl.length > PluginAuthenticationRedirectRequest.maxRedirectUrlLength) {
        return buildErrorResponse(request, 400, "invalid authentication redirect URL");
      }
      final redirectUri = Uri.tryParse(rawUrl);
      if (redirectUri == null || !redirectUri.isAbsolute) {
        return buildErrorResponse(request, 400, "invalid authentication redirect URL");
      }
      await _lifecycleService.submitAuthenticationRedirect(pluginId: pluginId, redirectUri: redirectUri);
      return buildOkJsonResponse(request: request, body: const SuccessEmptyResponse());
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request, 404, "plugin not found");
    } on PluginAuthenticationContinuationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication redirect failed", error, stackTrace);
      return buildErrorResponse(request, 500, "plugin authentication redirect failed");
    }
  }
}

class DeletePluginAuthenticationHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(HttpMethod.delete, "/plugin/:id/authentication");

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request, 400, "plugin id is required");
      return buildOkJsonResponse(
        request: request,
        body: await _lifecycleService.cancelAuthentication(pluginId: pluginId),
      );
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request, 404, "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on Object catch (error, stackTrace) {
      Log.w("DELETE ${request.path}: plugin authentication cancellation failed", error, stackTrace);
      return buildErrorResponse(request, 500, "plugin authentication cancellation failed");
    }
  }
}
