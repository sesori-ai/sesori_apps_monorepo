import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";

class PullRequestRefreshSettingsService {
  PullRequestRefreshSettingsService({required BridgeSettingsRepository bridgeSettingsRepository})
    : _bridgeSettingsRepository = bridgeSettingsRepository;

  final BridgeSettingsRepository _bridgeSettingsRepository;

  PullRequestRefreshSettingsResponse get currentSettings =>
      _response(settings: _bridgeSettingsRepository.currentSettings);

  Stream<PullRequestRefreshSettingsResponse> get changes => _bridgeSettingsRepository.settingsChanges
      .where(
        (change) =>
            change.previous.pullRequestRefreshIntervalSeconds != change.current.pullRequestRefreshIntervalSeconds,
      )
      .map((change) => _response(settings: change.current));

  Future<PullRequestRefreshSettingsResponse> update({required PullRequestRefreshSettingsRequest request}) async {
    final intervalSeconds = request.intervalSeconds;
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

class PullRequestRefreshIntervalOutOfRangeException implements Exception {
  final int intervalSeconds;

  const PullRequestRefreshIntervalOutOfRangeException({required this.intervalSeconds});

  int get minimumIntervalSeconds => minimumPullRequestRefreshIntervalSeconds;

  int get maximumIntervalSeconds => maximumPullRequestRefreshIntervalSeconds;

  @override
  String toString() => "PullRequestRefreshIntervalOutOfRangeException";
}
