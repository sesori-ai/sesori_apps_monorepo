import "package:sesori_shared/sesori_shared.dart";

import "../repositories/health_repository.dart";
import "request_handler.dart";

/// Handles `GET /global/health` — returns the bridge health snapshot.
class HealthCheckHandler({required final HealthRepository _healthRepository})
    extends GetRequestHandler<HealthResponse> {
  this : super("/global/health");

  @override
  Future<HealthResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _healthRepository.getHealth();
  }
}
