import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../services/health_check_service.dart";
import "request_handler.dart";

class HealthCheckHandler extends GetRequestHandler<HealthResponse> {
  final HealthCheckService _service;

  HealthCheckHandler({required HealthCheckService service}) : _service = service,
        super("/global/health");

  @override
  Future<HealthResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _service.check();
  }

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final result = await handle(
        request,
        pathParams: pathParams,
        queryParams: queryParams,
        fragment: fragment,
      );
      if (!result.healthy) {
        return RelayResponse(
          id: request.id,
          status: 503,
          headers: {"content-type": "application/json"},
          body: jsonEncode(result.toJson()),
        );
      }
      return buildOkJsonResponse(request, result);
    } on PluginApiException catch (err) {
      return buildErrorResponse(request, err.statusCode, err.toString());
    } on RelayResponse catch (err) {
      if (err.status >= 200 && err.status < 300) {
        throw buildErrorResponse(request, 500, "Internal Server Error: threw success response");
      } else {
        return err;
      }
    } catch (err) {
      return buildErrorResponse(request, 500, "Internal Server Error: $err");
    }
  }
}
