import "../api/sesori_server_api.dart";

sealed class AppClientStatusResult {
  const AppClientStatusResult();
}

final class AppClientRegistered extends AppClientStatusResult {
  const AppClientRegistered();
}

final class AppClientAbsent extends AppClientStatusResult {
  const AppClientAbsent();
}

final class AppClientStatusUnavailable extends AppClientStatusResult {
  const AppClientStatusUnavailable({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;
}

class AppClientStatusRepository {
  AppClientStatusRepository({required SesoriServerApi api}) : _api = api;

  final SesoriServerApi _api;

  Future<AppClientStatusResult> getStatus({
    required String accessToken,
    required bool wait,
  }) async {
    try {
      final response = await _api.getAppClientStatus(accessToken: accessToken, wait: wait);
      return response.registered ? const AppClientRegistered() : const AppClientAbsent();
    } on SesoriServerApiException catch (error, stackTrace) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        // COMPATIBILITY 2026-07-18 (v1.5.1): Auth servers predating app-client status return 404/405, so onboarding must fail open for older/custom deployments. Remove this fallback and its endpoint-omission tests after every supported auth server exposes GET /auth/app-clients/status.
        return AppClientStatusUnavailable(error: error, stackTrace: stackTrace);
      }
      return AppClientStatusUnavailable(error: error, stackTrace: stackTrace);
    } on Object catch (error, stackTrace) {
      return AppClientStatusUnavailable(error: error, stackTrace: stackTrace);
    }
  }
}
