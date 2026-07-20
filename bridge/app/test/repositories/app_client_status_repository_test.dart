import "package:sesori_bridge/src/api/app_client_status_response.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/repositories/app_client_status_repository.dart";
import "package:test/test.dart";

void main() {
  group("AppClientStatusRepository", () {
    test("maps strict true and false responses", () async {
      final api = _FakeSesoriServerApi();
      final repository = AppClientStatusRepository(api: api);

      api.response = const AppClientStatusResponse(registered: true);
      expect(await repository.getStatus(accessToken: "token", wait: false), isA<AppClientRegistered>());

      api.response = const AppClientStatusResponse(registered: false);
      expect(await repository.getStatus(accessToken: "token", wait: true), isA<AppClientAbsent>());
      expect(api.waitValues, equals([false, true]));
    });

    test("maps legacy endpoint omission statuses to unavailable", () async {
      for (final statusCode in [404, 405]) {
        final api = _FakeSesoriServerApi()
          ..error = SesoriServerApiException(
            statusCode: statusCode,
            uri: Uri.parse("https://auth.example.test/auth/app-clients/status"),
          );
        final result = await AppClientStatusRepository(
          api: api,
        ).getStatus(accessToken: "token", wait: false);

        expect(result, isA<AppClientStatusUnavailable>());
      }
    });

    test("maps transport and malformed-response failures to unavailable", () async {
      const error = FormatException("bad body");
      final api = _FakeSesoriServerApi()..error = error;

      final result = await AppClientStatusRepository(
        api: api,
      ).getStatus(accessToken: "token", wait: false);

      expect(result, isA<AppClientStatusUnavailable>());
      expect((result as AppClientStatusUnavailable).error, same(error));
    });
  });
}

class _FakeSesoriServerApi implements SesoriServerApi {
  AppClientStatusResponse response = const AppClientStatusResponse(registered: false);
  Object? error;
  final List<bool> waitValues = [];

  @override
  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken, required bool wait}) async {
    waitValues.add(wait);
    if (error != null) throw error!;
    return response;
  }
}
