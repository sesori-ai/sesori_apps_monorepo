import "package:injectable/injectable.dart";

import "../repositories/bridge_settings_repository.dart";
import "../repositories/models/bridge_settings_result.dart";

@lazySingleton
class BridgeSettingsService({required final BridgeSettingsRepository _repository}) {
  Future<BridgeSettingsLoadResult> load() => _repository.load();

  Future<PullRequestRefreshSettingsMutationResult> updatePullRequestRefresh({required int intervalSeconds}) =>
      _repository.updatePullRequestRefresh(intervalSeconds: intervalSeconds);

  Future<YoloSettingsMutationResult> updateYolo({required bool enabled}) => _repository.updateYolo(enabled: enabled);

  PullRequestRefreshSettingsUpdatePlan planPullRequestRefreshUpdate({
    required String input,
    required PullRequestRefreshSettingsBounds? bounds,
  }) {
    final intervalSeconds = int.tryParse(input.trim());
    if (intervalSeconds == null ||
        intervalSeconds <= 0 ||
        (bounds != null && !bounds.includes(intervalSeconds: intervalSeconds))) {
      return const PullRequestRefreshSettingsUpdateInvalid();
    }
    return PullRequestRefreshSettingsUpdateRequest(intervalSeconds: intervalSeconds);
  }
}

sealed class const PullRequestRefreshSettingsUpdatePlan();

final class const PullRequestRefreshSettingsUpdateRequest({required final int intervalSeconds})
    extends PullRequestRefreshSettingsUpdatePlan;

final class const PullRequestRefreshSettingsUpdateInvalid() extends PullRequestRefreshSettingsUpdatePlan;
