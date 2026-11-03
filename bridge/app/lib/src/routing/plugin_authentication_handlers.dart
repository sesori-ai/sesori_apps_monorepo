import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../services/plugin_lifecycle_service.dart";
import "request_handler.dart";

class PostPluginAuthenticationHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(method: HttpMethod.post, path: "/plugin/:id/authentication");

  @override
  Future<RelayResponse> handleInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request: request, status: 400, message: "plugin id is required");
      return buildOkJsonResponse(
        request: request,
        body: await _lifecycleService.authenticate(pluginId: pluginId),
      );
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on PluginAuthenticationChallengeUnavailableException {
      return buildErrorResponse(
        request: request,
        status: 500,
        message: "plugin authentication did not provide a challenge",
      );
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication failed", error, stackTrace);
      return buildErrorResponse(request: request, status: 500, message: "plugin authentication failed");
    }
  }
}

class PostPluginAuthenticationRedirectHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(method: HttpMethod.post, path: "/plugin/:id/authentication/redirect");

  @override
  Future<RelayResponse> handleInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request: request, status: 400, message: "plugin id is required");
      final body = request.body;
      if (body == null) {
        return buildErrorResponse(request: request, status: 400, message: "authentication redirect body is required");
      }
      final PluginAuthenticationRedirectRequest redirectRequest;
      try {
        redirectRequest = PluginAuthenticationRedirectRequest.fromJson(jsonDecodeMap(body));
      } on Object {
        return buildErrorResponse(request: request, status: 400, message: "invalid authentication redirect body");
      }
      final rawUrl = redirectRequest.redirectUrl;
      if (rawUrl.isEmpty || rawUrl.length > PluginAuthenticationRedirectRequest.maxRedirectUrlLength) {
        return buildErrorResponse(request: request, status: 400, message: "invalid authentication redirect URL");
      }
      final redirectUri = Uri.tryParse(rawUrl);
      if (redirectUri == null || !redirectUri.isAbsolute) {
        return buildErrorResponse(request: request, status: 400, message: "invalid authentication redirect URL");
      }
      await _lifecycleService.submitAuthenticationRedirect(pluginId: pluginId, redirectUri: redirectUri);
      return buildOkJsonResponse(request: request, body: const SuccessEmptyResponse());
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on PluginAuthenticationContinuationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication redirect failed", error, stackTrace);
      return buildErrorResponse(request: request, status: 500, message: "plugin authentication redirect failed");
    }
  }
}

class PostPluginAuthenticationCodeHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(method: HttpMethod.post, path: "/plugin/:id/authentication/code");

  @override
  Future<RelayResponse> handleInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request: request, status: 400, message: "plugin id is required");
      final body = request.body;
      if (body == null) {
        return buildErrorResponse(request: request, status: 400, message: "authentication code body is required");
      }
      final PluginAuthenticationCodeRequest codeRequest;
      try {
        codeRequest = PluginAuthenticationCodeRequest.fromJson(jsonDecodeMap(body));
      } on Object {
        return buildErrorResponse(request: request, status: 400, message: "invalid authentication code body");
      }
      final code = PluginAuthenticationCodeRequest.normalizeCode(code: codeRequest.code);
      if (code == null) {
        return buildErrorResponse(request: request, status: 400, message: "invalid authentication code");
      }
      await _lifecycleService.submitAuthenticationCode(pluginId: pluginId, code: code);
      return buildOkJsonResponse(request: request, body: const SuccessEmptyResponse());
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on PluginAuthenticationContinuationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on Object catch (error, stackTrace) {
      Log.w("POST ${request.path}: plugin authentication code submission failed", error, stackTrace);
      return buildErrorResponse(request: request, status: 500, message: "plugin authentication code submission failed");
    }
  }
}

class DeletePluginAuthenticationHandler({required final PluginLifecycleService _lifecycleService})
    extends RequestHandlerBase {
  this : super(method: HttpMethod.delete, path: "/plugin/:id/authentication");

  @override
  Future<RelayResponse> handleInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) async {
    try {
      final pluginId = targetParams.pathParams["id"];
      if (pluginId == null) return buildErrorResponse(request: request, status: 400, message: "plugin id is required");
      return buildOkJsonResponse(
        request: request,
        body: await _lifecycleService.cancelAuthentication(pluginId: pluginId),
      );
    } on PluginManagementPluginNotFoundException {
      return buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on PluginAuthenticationConflictException catch (error) {
      return buildJsonErrorResponse(request: request, status: 409, body: error.conflict.toJson());
    } on Object catch (error, stackTrace) {
      Log.w("DELETE ${request.path}: plugin authentication cancellation failed", error, stackTrace);
      return buildErrorResponse(request: request, status: 500, message: "plugin authentication cancellation failed");
    }
  }
}
