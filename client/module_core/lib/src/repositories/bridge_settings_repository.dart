import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_settings_api.dart";
import "models/bridge_settings_result.dart";

@lazySingleton
class BridgeSettingsRepository({required final BridgeSettingsApi _bridgeSettingsApi}) {
  Future<BridgeSettingsLoadResult> load() async {
    final aggregate = await _bridgeSettingsApi.getBridgeSettings();
    switch (aggregate) {
      case SuccessResponse(:final data):
        return BridgeSettingsLoadSupported(response: data);
      case ErrorResponse(error: NonSuccessCodeError(errorCode: 404)):
        break;
      case ErrorResponse(:final error):
        return BridgeSettingsLoadFailure(error: error);
    }

    return switch (await _bridgeSettingsApi.getPullRequestRefreshSettings()) {
      SuccessResponse(:final data) => BridgeSettingsLoadLegacyPartial(pullRequestRefresh: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const BridgeSettingsLoadUnsupported(),
      ErrorResponse(:final error) => BridgeSettingsLoadFailure(error: error),
    };
  }

  Future<PullRequestRefreshSettingsMutationResult> updatePullRequestRefresh({required int intervalSeconds}) async {
    return switch (await _bridgeSettingsApi.update(
      update: BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: intervalSeconds),
    )) {
      BridgeSettingUpdateApiCommitted(
        update: PullRequestRefreshIntervalSettingUpdate(:final intervalSeconds),
      ) =>
        PullRequestRefreshSettingsMutationCommitted(
          response: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
        ),
      BridgeSettingUpdateApiCommitted() => const PullRequestRefreshSettingsMutationUncertain(),
      BridgeSettingUpdateApiRejected(
        rejection: PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection(
          :final minimumIntervalSeconds,
          :final maximumIntervalSeconds,
        ),
      )
          when minimumIntervalSeconds <= maximumIntervalSeconds =>
        PullRequestRefreshSettingsMutationRejected(
          bounds: PullRequestRefreshSettingsBounds(
            minimumIntervalSeconds: minimumIntervalSeconds,
            maximumIntervalSeconds: maximumIntervalSeconds,
          ),
        ),
      BridgeSettingUpdateApiRejected(:final error) => PullRequestRefreshSettingsMutationFailure(error: error),
      BridgeSettingUpdateApiFailure(error: NonSuccessCodeError(errorCode: 404)) =>
        const PullRequestRefreshSettingsMutationUnsupported(),
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) => const PullRequestRefreshSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => PullRequestRefreshSettingsMutationFailure(error: error),
    };
  }

  Future<YoloSettingsMutationResult> updateYolo({required bool enabled}) async {
    return switch (await _bridgeSettingsApi.update(update: BridgeSettingUpdate.yolo(enabled: enabled))) {
      BridgeSettingUpdateApiCommitted(update: YoloSettingUpdate(:final enabled)) => YoloSettingsMutationCommitted(
        response: YoloSettingsResponse(enabled: enabled),
      ),
      BridgeSettingUpdateApiCommitted() => const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiRejected(:final error) => YoloSettingsMutationFailure(error: error),
      BridgeSettingUpdateApiFailure(error: NonSuccessCodeError(errorCode: 404)) =>
        const YoloSettingsMutationUnsupported(),
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) => const YoloSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => YoloSettingsMutationFailure(error: error),
    };
  }
}
