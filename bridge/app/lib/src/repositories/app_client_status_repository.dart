import "../api/sesori_server_api.dart";

sealed class const AppClientStatusResult();

final class const AppClientRegistered() extends AppClientStatusResult;

final class const AppClientAbsent() extends AppClientStatusResult;

final class const AppClientStatusUnavailable({required final Object error, required final StackTrace stackTrace})
    extends AppClientStatusResult;

class AppClientStatusRepository({required final SesoriServerApi _api}) {
  Future<AppClientStatusResult> getStatus({required String accessToken}) async {
    try {
      final response = await _api.getAppClientStatus(accessToken: accessToken);
      return response.registered ? const AppClientRegistered() : const AppClientAbsent();
    } on Object catch (error, stackTrace) {
      return AppClientStatusUnavailable(error: error, stackTrace: stackTrace);
    }
  }
}
