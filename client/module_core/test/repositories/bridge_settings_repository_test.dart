import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_settings_api.dart";
import "package:sesori_dart_core/src/repositories/bridge_settings_repository.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsApi() extends Mock implements BridgeSettingsApi;

void main() {
  late _MockBridgeSettingsApi api;
  late BridgeSettingsRepository repository;

  setUp(() {
    api = _MockBridgeSettingsApi();
    repository = BridgeSettingsRepository(bridgeSettingsApi: api);
  });

  test("loads the aggregate snapshot", () async {
    const response = BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      yolo: YoloSettingsResponse(enabled: true),
      warmUpPluginsOnSessionOpen: true,
    );
    when(api.getBridgeSettings).thenAnswer((_) async => ApiResponse.success(response));

    final result = await repository.load();

    expect((result as BridgeSettingsLoadSupported).response, response);
  });

  test("a 404 on the aggregate route is unsupported", () async {
    when(api.getBridgeSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    expect(await repository.load(), isA<BridgeSettingsLoadUnsupported>());
    verify(api.getBridgeSettings).called(1);
  });

  test("keeps the original error of any other aggregate failure", () async {
    final error = ApiError.generic();
    when(api.getBridgeSettings).thenAnswer((_) async => ApiResponse.error(error));

    final result = await repository.load();

    expect((result as BridgeSettingsLoadFailure).error, same(error));
  });

  test("maps every setting mutation response", () async {
    when(() => api.update(update: const BridgeSettingUpdate.yolo(enabled: true))).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(update: BridgeSettingUpdate.yolo(enabled: true)),
    );
    when(
      () => api.update(update: const BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: false)),
    ).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(
        update: BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: false),
      ),
    );

    final yolo = await repository.updateYolo(enabled: true);
    final warmup = await repository.updatePluginWarmup(enabled: false);

    expect((yolo as YoloSettingsMutationCommitted).response.enabled, isTrue);
    expect((warmup as PluginWarmupSettingsMutationCommitted).enabled, isFalse);
  });

  test("maps uncertain transport outcomes and failures", () async {
    final rejected = NonSuccessCodeError(errorCode: 400, rawErrorString: null);
    when(() => api.update(update: const BridgeSettingUpdate.yolo(enabled: true))).thenAnswer(
      (_) async => BridgeSettingUpdateApiFailure(error: ApiError.emptyResponse()),
    );
    when(
      () => api.update(update: const BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: false)),
    ).thenAnswer((_) async => BridgeSettingUpdateApiFailure(error: rejected));

    final yolo = await repository.updateYolo(enabled: true);
    final warmup = await repository.updatePluginWarmup(enabled: false);

    expect(yolo, isA<YoloSettingsMutationUncertain>());
    expect((warmup as PluginWarmupSettingsMutationFailure).error, same(rejected));
  });
}
