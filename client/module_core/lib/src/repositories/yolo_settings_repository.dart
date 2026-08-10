import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_settings_api.dart";
import "../capabilities/relay/relay_client.dart";
import "models/yolo_settings_result.dart";

@lazySingleton
class YoloSettingsRepository {
  YoloSettingsRepository({required BridgeSettingsApi bridgeSettingsApi}) : _bridgeSettingsApi = bridgeSettingsApi;

  final BridgeSettingsApi _bridgeSettingsApi;

  Future<YoloSettingsLoadResult> load() async {
    return switch (await _bridgeSettingsApi.getYoloSettings()) {
      SuccessResponse(:final data) => YoloSettingsLoadSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const YoloSettingsLoadUnsupported(),
      ErrorResponse(:final error) => YoloSettingsLoadFailure(error: error),
    };
  }

  Future<YoloSettingsMutationResult> update({required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(update: BridgeSettingUpdate.yolo(enabled: enabled))) {
      BridgeSettingUpdateApiCommitted(update: YoloSettingUpdate(:final enabled)) => YoloSettingsMutationCommitted(
        response: YoloSettingsResponse(enabled: enabled),
      ),
      BridgeSettingUpdateApiCommitted(update: UnknownBridgeSettingUpdate()) => const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiCommitted(update: PullRequestRefreshIntervalSettingUpdate()) =>
        const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiRejected(:final error) => YoloSettingsMutationFailure(error: error),
      BridgeSettingUpdateApiFailure(error: NonSuccessCodeError(errorCode: 404)) =>
        const YoloSettingsMutationUnsupported(),
      BridgeSettingUpdateApiFailure(error: final error) when _isUncertain(error: error) =>
        const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => YoloSettingsMutationFailure(error: error),
    };
  }
}

bool _isUncertain({required ApiError error}) => switch (error) {
  JsonParsingError() || EmptyResponseError() => true,
  DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()) => true,
  GenericError() || NotAuthenticatedError() || NonSuccessCodeError() || DartHttpClientError() => false,
};
