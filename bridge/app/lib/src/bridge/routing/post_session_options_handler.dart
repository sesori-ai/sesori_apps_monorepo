import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../services/session_options_service.dart";
import "request_handler.dart";

class PostSessionOptionsHandler({
  required final SessionOptionsService _service,
  required Set<String> pluginIds,
}) extends RequestHandlerBase {
  this : super(HttpMethod.post, "/session/options");

  final Set<String> _pluginIds = Set.unmodifiable(pluginIds);

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final rawBody = request.body;
    if (rawBody == null) return _error(request: request, status: 400, code: SessionOptionsErrorCode.unknown);

    final PluginProjectIdRequest body;
    try {
      body = PluginProjectIdRequest.fromJson(jsonDecodeMap(rawBody));
    } on Object {
      return _error(request: request, status: 400, code: SessionOptionsErrorCode.unknown);
    }
    final projectId = body.projectId.trim();
    final pluginId = body.pluginId.trim();
    if (projectId.isEmpty ||
        pluginId.isEmpty ||
        projectId != body.projectId ||
        pluginId != body.pluginId ||
        !_pluginIds.contains(pluginId)) {
      return _error(request: request, status: 400, code: SessionOptionsErrorCode.unknown);
    }

    final refresh = queryParams["refresh"];
    if (refresh != null && refresh != "false" && refresh != "true") {
      return _error(request: request, status: 400, code: SessionOptionsErrorCode.unknown);
    }

    final SessionOptionsOutcome outcome;
    try {
      outcome = switch (refresh) {
        null => await _service.loadDynamic(pluginId: pluginId, projectId: projectId),
        "false" => await _service.loadCacheOnly(pluginId: pluginId, projectId: projectId),
        "true" => await _service.refreshExplicit(pluginId: pluginId, projectId: projectId),
        _ => throw StateError("validated refresh query has an unsupported value"),
      };
    } on Object catch (error, stackTrace) {
      Log.w("Session options request failed", error, stackTrace);
      return _error(request: request, status: 500, code: SessionOptionsErrorCode.unknown);
    }

    return switch (outcome) {
      SessionOptionsAvailable(:final response) => _jsonResponse(
        request: request,
        status: 200,
        body: response.toJson(),
      ),
      SessionOptionsCacheUnavailable() => _error(
        request: request,
        status: 503,
        code: SessionOptionsErrorCode.cacheUnavailable,
      ),
      SessionOptionsProjectNotFound() => _error(
        request: request,
        status: 404,
        code: SessionOptionsErrorCode.projectNotFound,
      ),
      SessionOptionsRefreshFailedRetained() => _error(
        request: request,
        status: 502,
        code: SessionOptionsErrorCode.refreshFailedRetained,
      ),
      SessionOptionsRefreshFailedUnavailable() => _error(
        request: request,
        status: 502,
        code: SessionOptionsErrorCode.refreshFailedUnavailable,
      ),
      SessionOptionsAutomaticNoOp() => _unexpectedAutomaticNoOp(request: request),
    };
  }

  RelayResponse _unexpectedAutomaticNoOp({required RelayRequest request}) {
    Log.w("Explicit session options request produced an automatic no-op outcome");
    return _error(request: request, status: 500, code: SessionOptionsErrorCode.unknown);
  }

  RelayResponse _error({
    required RelayRequest request,
    required int status,
    required SessionOptionsErrorCode code,
  }) {
    return _jsonResponse(
      request: request,
      status: status,
      body: SessionOptionsErrorResponse(code: code).toJson(),
    );
  }

  RelayResponse _jsonResponse({
    required RelayRequest request,
    required int status,
    required Map<String, dynamic> body,
  }) {
    return RelayResponse(
      id: request.id,
      status: status,
      headers: const {"content-type": "application/json"},
      body: jsonEncode(body),
    );
  }
}
