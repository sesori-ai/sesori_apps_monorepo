import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";

// COMPATIBILITY 2026-10-25 (v1.10.0): Released apps still read and save the pull request refresh interval,
// which no longer has any effect. Remove once public apps older than v1.9.2 are unsupported.
class PullRequestRefreshSettingsService({required final BridgeSettingsRepository _bridgeSettingsRepository}) {
  Future<PullRequestRefreshSettingsResponse> readCommittedSettings() async {
    return _response(settings: await _bridgeSettingsRepository.readCommittedSettings());
  }

  Future<PullRequestRefreshSettingsResponse> update({required int intervalSeconds}) async {
    if (intervalSeconds < minimumPullRequestRefreshIntervalSeconds ||
        intervalSeconds > maximumPullRequestRefreshIntervalSeconds) {
      throw PullRequestRefreshIntervalOutOfRangeException(intervalSeconds: intervalSeconds);
    }

    final committed = await _bridgeSettingsRepository.mutateSettings(
      mutation: ({required current}) => current.pullRequestRefreshIntervalSeconds == intervalSeconds
          ? current
          : current.copyWith(pullRequestRefreshIntervalSeconds: intervalSeconds),
    );
    return _response(settings: committed);
  }

  PullRequestRefreshSettingsResponse _response({required BridgeSettings settings}) {
    return PullRequestRefreshSettingsResponse(
      intervalSeconds: settings.pullRequestRefreshIntervalSeconds,
    );
  }
}

class const PullRequestRefreshIntervalOutOfRangeException({required final int intervalSeconds}) implements Exception {
  int get minimumIntervalSeconds => minimumPullRequestRefreshIntervalSeconds;

  int get maximumIntervalSeconds => maximumPullRequestRefreshIntervalSeconds;

  @override
  String toString() =>
      "PullRequestRefreshIntervalOutOfRangeException(intervalSeconds: $intervalSeconds, "
      "validRange: $minimumIntervalSeconds..$maximumIntervalSeconds)";
}
