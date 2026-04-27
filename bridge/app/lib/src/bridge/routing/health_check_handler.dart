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
}
