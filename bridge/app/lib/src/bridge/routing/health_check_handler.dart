import "package:sesori_shared/sesori_shared.dart";

import "../repositories/health_repository.dart";
import "request_handler.dart";

/// Handles `GET /global/health` — returns the bridge health snapshot.
class HealthCheckHandler extends GetRequestHandler<HealthResponse> {
  final HealthRepository _healthRepository;

  HealthCheckHandler({required HealthRepository healthRepository})
    : _healthRepository = healthRepository,
      super("/global/health");

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
