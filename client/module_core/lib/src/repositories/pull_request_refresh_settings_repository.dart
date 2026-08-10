import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_settings_api.dart";
import "models/pull_request_refresh_settings_result.dart";

@lazySingleton
class PullRequestRefreshSettingsRepository {
  PullRequestRefreshSettingsRepository({required BridgeSettingsApi bridgeSettingsApi})
    : _bridgeSettingsApi = bridgeSettingsApi;

  final BridgeSettingsApi _bridgeSettingsApi;

  Future<PullRequestRefreshSettingsLoadResult> load() async {
    return switch (await _bridgeSettingsApi.getPullRequestRefreshSettings()) {
      SuccessResponse(:final data) => PullRequestRefreshSettingsLoadSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PullRequestRefreshSettingsLoadUnsupported(),
      ErrorResponse(:final error) => PullRequestRefreshSettingsLoadFailure(error: error),
    };
  }

  Future<PullRequestRefreshSettingsMutationResult> update({required int intervalSeconds}) async {
    return switch (await _bridgeSettingsApi.update(
      update: BridgeSettingUpdate.pullRequestRefreshInterval(
        intervalSeconds: intervalSeconds,
      ),
    )) {
      BridgeSettingUpdateApiCommitted(
        update: PullRequestRefreshIntervalSettingUpdate(:final intervalSeconds),
      ) =>
        PullRequestRefreshSettingsMutationCommitted(
          response: PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds),
        ),
      BridgeSettingUpdateApiCommitted(update: UnknownBridgeSettingUpdate()) =>
        const PullRequestRefreshSettingsMutationUncertain(),
      BridgeSettingUpdateApiCommitted(update: YoloSettingUpdate()) =>
        const PullRequestRefreshSettingsMutationUncertain(),
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
      BridgeSettingUpdateApiFailure(isCommitUncertain: true) =>
        const PullRequestRefreshSettingsMutationUncertain(),
      BridgeSettingUpdateApiFailure(:final error) => PullRequestRefreshSettingsMutationFailure(error: error),
    };
  }
}
