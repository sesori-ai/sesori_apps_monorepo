import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_settings_api.dart";
import "package:sesori_dart_core/src/repositories/bridge_settings_repository.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsApi extends Mock implements BridgeSettingsApi;

void main() {
  late _MockBridgeSettingsApi api;
  late BridgeSettingsRepository repository;

  setUp(() {
    api = _MockBridgeSettingsApi();
    repository = BridgeSettingsRepository(bridgeSettingsApi: api);
  });

  test("loads the aggregate snapshot without calling the legacy route", () async {
    const response = BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      yolo: YoloSettingsResponse(enabled: true),
    );
    when(api.getBridgeSettings).thenAnswer((_) async => ApiResponse.success(response));

    final result = await repository.load();

    expect((result as BridgeSettingsLoadSupported).response, response);
    verifyNever(api.getPullRequestRefreshSettings);
  });

  test("falls back to legacy PR settings only when aggregate GET is 404", () async {
    when(api.getBridgeSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    when(api.getPullRequestRefreshSettings).thenAnswer(
      (_) async => ApiResponse.success(const PullRequestRefreshSettingsResponse(intervalSeconds: 45)),
    );

    final result = await repository.load();

    expect((result as BridgeSettingsLoadLegacyPartial).pullRequestRefresh.intervalSeconds, 45);
  });

  test("does not fall back after a non-404 aggregate failure", () async {
    final error = ApiError.generic();
    when(api.getBridgeSettings).thenAnswer((_) async => ApiResponse.error(error));

    final result = await repository.load();

    expect((result as BridgeSettingsLoadFailure).error, same(error));
    verifyNever(api.getPullRequestRefreshSettings);
  });

  test("reports fully unsupported when aggregate and legacy routes are 404", () async {
    final notFound = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
    when(api.getBridgeSettings).thenAnswer((_) async => ApiResponse.error(notFound));
    when(api.getPullRequestRefreshSettings).thenAnswer((_) async => ApiResponse.error(notFound));

    expect(await repository.load(), isA<BridgeSettingsLoadUnsupported>());
  });

  test("maps both setting mutation responses", () async {
    when(
      () => api.update(update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45)),
    ).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(
        update: BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 46),
      ),
    );
    when(() => api.update(update: const BridgeSettingUpdate.yolo(enabled: true))).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(update: BridgeSettingUpdate.yolo(enabled: true)),
    );

    final pullRequest = await repository.updatePullRequestRefresh(intervalSeconds: 45);
    final yolo = await repository.updateYolo(enabled: true);

    expect((pullRequest as PullRequestRefreshSettingsMutationCommitted).response.intervalSeconds, 46);
    expect((yolo as YoloSettingsMutationCommitted).response.enabled, isTrue);
  });

  test("maps PR bounds rejections and uncertain transport outcomes", () async {
    final rejectionError = NonSuccessCodeError(errorCode: 400, rawErrorString: null);
    when(
      () => api.update(update: const BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 10)),
    ).thenAnswer(
      (_) async => BridgeSettingUpdateApiRejected(
        rejection: const BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
          minimumIntervalSeconds: 15,
          maximumIntervalSeconds: 3600,
        ),
        error: rejectionError,
      ),
    );
    when(() => api.update(update: const BridgeSettingUpdate.yolo(enabled: true))).thenAnswer(
      (_) async => BridgeSettingUpdateApiFailure(error: ApiError.emptyResponse()),
    );

    final pullRequest = await repository.updatePullRequestRefresh(intervalSeconds: 10);
    final yolo = await repository.updateYolo(enabled: true);

    final bounds = (pullRequest as PullRequestRefreshSettingsMutationRejected).bounds;
    expect(bounds.minimumIntervalSeconds, 15);
    expect(bounds.maximumIntervalSeconds, 3600);
    expect(yolo, isA<YoloSettingsMutationUncertain>());
  });
}
