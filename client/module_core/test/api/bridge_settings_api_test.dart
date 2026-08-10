import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_settings_api.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  late _MockRelayHttpApiClient client;
  late BridgeSettingsApi api;

  setUp(() {
    client = _MockRelayHttpApiClient();
    api = BridgeSettingsApi(client: client);
  });

  test("GET parses the committed pull request refresh interval", () async {
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

    final result = await api.getPullRequestRefreshSettings();

    expect((result as SuccessResponse<PullRequestRefreshSettingsResponse>).data.intervalSeconds, 30);
  });

  test("GET parses the aggregate bridge settings", () async {
    when(
      () => client.get<BridgeSettingsResponse>(
        "/settings",
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as BridgeSettingsResponse Function(Map<String, dynamic>);
      return ApiResponse.success(
        fromJson({
          "pullRequestRefresh": {"intervalSeconds": 30},
          "yolo": {"enabled": true},
        }),
      );
    });

    final result = await api.getBridgeSettings();

    final settings = (result as SuccessResponse<BridgeSettingsResponse>).data;
    expect(settings.pullRequestRefresh.intervalSeconds, 30);
    expect(settings.yolo.enabled, isTrue);
  });

  test("PATCH serializes and parses a committed setting variant", () async {
    when(
      () => client.patch<BridgeSettingUpdate>(
        "/settings",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as BridgeSettingUpdate Function(Map<String, dynamic>);
      return ApiResponse.success(
        fromJson(const {"type": "pullRequestRefreshInterval", "intervalSeconds": 45}),
      );
    });
    const update = BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45);

    final result = await api.update(update: update);

    expect((result as BridgeSettingUpdateApiCommitted).update, update);
    final body = verify(
      () => client.patch<BridgeSettingUpdate>(
        "/settings",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, update.toJson());
  });

  test("PATCH serializes and parses a committed YOLO setting", () async {
    when(
      () => client.patch<BridgeSettingUpdate>(
        "/settings",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as BridgeSettingUpdate Function(Map<String, dynamic>);
      return ApiResponse.success(fromJson(const {"type": "yolo", "enabled": true}));
    });
    const update = BridgeSettingUpdate.yolo(enabled: true);

    final result = await api.update(update: update);

    expect((result as BridgeSettingUpdateApiCommitted).update, update);
    final body = verify(
      () => client.patch<BridgeSettingUpdate>(
        "/settings",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, update.toJson());
  });

  test("PATCH parses a typed rejection at the API boundary", () async {
    const rejection = BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
      minimumIntervalSeconds: 15,
      maximumIntervalSeconds: 3600,
    );
    final error = NonSuccessCodeError(
      errorCode: 400,
      rawErrorString: jsonEncode(rejection.toJson()),
    );
    _stubFailure(client: client, error: error);

    final result = await api.update(
      update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 10),
    );

    expect((result as BridgeSettingUpdateApiRejected).rejection, rejection);
    expect(result.error, same(error));
  });

  test("PATCH preserves malformed rejection and other transport failures", () async {
    final malformed = ApiError.nonSuccessCode(errorCode: 400, rawErrorString: "not-json");
    _stubFailure(client: client, error: malformed);
    final malformedResult = await api.update(
      update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 10),
    );
    expect((malformedResult as BridgeSettingUpdateApiFailure).error, same(malformed));

    final unavailable = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
    _stubFailure(client: client, error: unavailable);
    final unavailableResult = await api.update(
      update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 30),
    );
    expect((unavailableResult as BridgeSettingUpdateApiFailure).error, same(unavailable));
  });
}

void _stubFailure({required _MockRelayHttpApiClient client, required ApiError error}) {
  when(
    () => client.patch<BridgeSettingUpdate>(
      "/settings",
      body: any(named: "body"),
      fromJson: any(named: "fromJson"),
    ),
  ).thenAnswer((_) async => ApiResponse.error(error));
}
