import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_settings_api.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/repositories/models/pull_request_refresh_settings_result.dart";
import "package:sesori_dart_core/src/repositories/pull_request_refresh_settings_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsApi extends Mock implements BridgeSettingsApi {}

void main() {
  late _MockBridgeSettingsApi bridgeSettingsApi;
  late PullRequestRefreshSettingsRepository repository;

  setUpAll(() {
    registerFallbackValue(const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 30));
  });

  setUp(() {
    bridgeSettingsApi = _MockBridgeSettingsApi();
    repository = PullRequestRefreshSettingsRepository(bridgeSettingsApi: bridgeSettingsApi);
  });

  test("load distinguishes supported, unsupported, and failed responses", () async {
    when(bridgeSettingsApi.getPullRequestRefreshSettings).thenAnswer(
      (_) async => ApiResponse.success(const PullRequestRefreshSettingsResponse(intervalSeconds: 30)),
    );
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadSupported>());

    when(bridgeSettingsApi.getPullRequestRefreshSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadUnsupported>());

    when(bridgeSettingsApi.getPullRequestRefreshSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadFailure>());
  });

  test("update sends the cadence variant and returns the bridge-committed value", () async {
    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(
        update: BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 46),
      ),
    );

    final result = await repository.update(intervalSeconds: 45);

    expect((result as PullRequestRefreshSettingsMutationCommitted).response.intervalSeconds, 46);
    verify(
      () => bridgeSettingsApi.update(
        update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45),
      ),
    ).called(1);
  });

  test("update maps typed valid bounds and rejects invalid rejection variants", () async {
    final error = NonSuccessCodeError(errorCode: 400, rawErrorString: "typed");
    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => BridgeSettingUpdateApiRejected(
        rejection: const BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
          minimumIntervalSeconds: 15,
          maximumIntervalSeconds: 3600,
        ),
        error: error,
      ),
    );

    final result = await repository.update(intervalSeconds: 10);

    final bounds = (result as PullRequestRefreshSettingsMutationRejected).bounds;
    expect(bounds.minimumIntervalSeconds, 15);
    expect(bounds.maximumIntervalSeconds, 3600);

    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => BridgeSettingUpdateApiRejected(
        rejection: const BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
          minimumIntervalSeconds: 1800,
          maximumIntervalSeconds: 20,
        ),
        error: error,
      ),
    );
    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationFailure>());

    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => BridgeSettingUpdateApiRejected(
        rejection: const BridgeSettingUpdateRejection.unknown(),
        error: error,
      ),
    );
    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationFailure>());
  });

  test("update distinguishes unsupported, uncertain, and ordinary failures", () async {
    final unsupported = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer((_) async => BridgeSettingUpdateApiFailure(error: unsupported));
    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationUnsupported>());

    final uncertainErrors = <ApiError>[
      ApiError.jsonParsing("not-json"),
      ApiError.emptyResponse(),
      ApiError.dartHttpClient(TimeoutException("timed out")),
      ApiError.dartHttpClient(const RelayResponseLostException(message: "lost")),
    ];
    for (final error in uncertainErrors) {
      when(
        () => bridgeSettingsApi.update(update: any(named: "update")),
      ).thenAnswer((_) async => BridgeSettingUpdateApiFailure(error: error));
      expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationUncertain>());
    }

    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer((_) async => BridgeSettingUpdateApiFailure(error: ApiError.generic()));
    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationFailure>());
  });

  test("an unexpected committed variant stays uncertain", () async {
    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(update: BridgeSettingUpdate.unknown()),
    );

    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationUncertain>());

    when(
      () => bridgeSettingsApi.update(update: any(named: "update")),
    ).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(update: BridgeSettingUpdate.yolo(enabled: true)),
    );

    expect(await repository.update(intervalSeconds: 45), isA<PullRequestRefreshSettingsMutationUncertain>());
  });
}
