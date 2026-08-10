import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_settings_api.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/repositories/models/yolo_settings_result.dart";
import "package:sesori_dart_core/src/repositories/yolo_settings_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsApi extends Mock implements BridgeSettingsApi {}

void main() {
  late _MockBridgeSettingsApi api;
  late YoloSettingsRepository repository;

  setUpAll(() => registerFallbackValue(const BridgeSettingUpdate.yolo(enabled: false)));

  setUp(() {
    api = _MockBridgeSettingsApi();
    repository = YoloSettingsRepository(bridgeSettingsApi: api);
  });

  test("load distinguishes supported, unsupported, and failed responses", () async {
    when(api.getYoloSettings).thenAnswer((_) async => ApiResponse.success(const YoloSettingsResponse(enabled: true)));
    expect(await repository.load(), isA<YoloSettingsLoadSupported>());

    when(api.getYoloSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    expect(await repository.load(), isA<YoloSettingsLoadUnsupported>());

    when(api.getYoloSettings).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    expect(await repository.load(), isA<YoloSettingsLoadFailure>());
  });

  test("update sends YOLO and uses the bridge-committed value", () async {
    when(() => api.update(update: any(named: "update"))).thenAnswer(
      (_) async => const BridgeSettingUpdateApiCommitted(update: BridgeSettingUpdate.yolo(enabled: false)),
    );

    final result = await repository.update(enabled: true);

    expect((result as YoloSettingsMutationCommitted).response.enabled, isFalse);
    verify(() => api.update(update: const BridgeSettingUpdate.yolo(enabled: true))).called(1);
  });

  test("update distinguishes unsupported, uncertain, and ordinary failures", () async {
    when(() => api.update(update: any(named: "update"))).thenAnswer(
      (_) async => BridgeSettingUpdateApiFailure(
        error: ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null),
      ),
    );
    expect(await repository.update(enabled: true), isA<YoloSettingsMutationUnsupported>());

    for (final error in <ApiError>[
      ApiError.jsonParsing("not-json"),
      ApiError.emptyResponse(),
      ApiError.dartHttpClient(TimeoutException("timed out")),
      ApiError.dartHttpClient(const RelayResponseLostException(message: "lost")),
    ]) {
      when(() => api.update(update: any(named: "update"))).thenAnswer(
        (_) async => BridgeSettingUpdateApiFailure(error: error),
      );
      expect(await repository.update(enabled: true), isA<YoloSettingsMutationUncertain>());
    }

    when(() => api.update(update: any(named: "update"))).thenAnswer(
      (_) async => BridgeSettingUpdateApiFailure(error: ApiError.generic()),
    );
    expect(await repository.update(enabled: true), isA<YoloSettingsMutationFailure>());
  });
}
