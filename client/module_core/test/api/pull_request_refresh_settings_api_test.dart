import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/pull_request_refresh_settings_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  late _MockRelayHttpApiClient client;
  late PullRequestRefreshSettingsApi api;

  setUp(() {
    client = _MockRelayHttpApiClient();
    api = PullRequestRefreshSettingsApi(client: client);
  });

  test("GET parses the committed refresh interval", () async {
    when(
      () => client.get<PullRequestRefreshSettingsResponse>(
        "/settings/pull-request-refresh",
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson =
          invocation.namedArguments[#fromJson] as PullRequestRefreshSettingsResponse Function(Map<String, dynamic>);
      return ApiResponse.success(fromJson({"intervalSeconds": 30}));
    });

    final result = await api.getSettings();

    expect((result as SuccessResponse<PullRequestRefreshSettingsResponse>).data.intervalSeconds, 30);
  });

  test("PATCH serializes the shared request and parses the committed value", () async {
    when(
      () => client.patch<PullRequestRefreshSettingsResponse>(
        "/settings/pull-request-refresh",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(const PullRequestRefreshSettingsResponse(intervalSeconds: 45)));

    await api.updateSettings(request: const PullRequestRefreshSettingsRequest(intervalSeconds: 45));

    final body = verify(
      () => client.patch<PullRequestRefreshSettingsResponse>(
        "/settings/pull-request-refresh",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, const PullRequestRefreshSettingsRequest(intervalSeconds: 45).toJson());
  });
}
