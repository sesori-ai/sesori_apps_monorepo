import "../api/sesori_server_api.dart";

sealed class const AppClientStatusResult();

final class const AppClientRegistered() extends AppClientStatusResult;

final class const AppClientAbsent() extends AppClientStatusResult;

final class const AppClientStatusUnavailable({required this.error, required this.stackTrace}) extends AppClientStatusResult {
  final Object error;
  final StackTrace stackTrace;
}

class AppClientStatusRepository({required SesoriServerApi api}) {
  this : _api = api;

  final SesoriServerApi _api;

  Future<AppClientStatusResult> getStatus({required String accessToken}) async {
    try {
      final response = await _api.getAppClientStatus(accessToken: accessToken);
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
