import "package:injectable/injectable.dart";

import "../repositories/models/pull_request_refresh_settings_result.dart";
import "../repositories/pull_request_refresh_settings_repository.dart";

@lazySingleton
class PullRequestRefreshSettingsService {
  PullRequestRefreshSettingsService({required PullRequestRefreshSettingsRepository repository})
    : _repository = repository;

  final PullRequestRefreshSettingsRepository _repository;

  Future<PullRequestRefreshSettingsLoadResult> load() => _repository.load();

  Future<PullRequestRefreshSettingsMutationResult> update({required int intervalSeconds}) =>
      _repository.update(intervalSeconds: intervalSeconds);

  PullRequestRefreshSettingsUpdatePlan planUpdate({
    required String input,
    required PullRequestRefreshSettingsBounds? bounds,
  }) {
    final intervalSeconds = int.tryParse(input.trim());
    if (intervalSeconds == null || (bounds != null && !bounds.includes(intervalSeconds: intervalSeconds))) {
      return const PullRequestRefreshSettingsUpdateInvalid();
    }
    return PullRequestRefreshSettingsUpdateRequest(
      intervalSeconds: intervalSeconds,
    );
  }
}

sealed class PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdatePlan();
}

final class PullRequestRefreshSettingsUpdateRequest extends PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdateRequest({required this.intervalSeconds});

  final int intervalSeconds;
}

final class PullRequestRefreshSettingsUpdateInvalid extends PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdateInvalid();
}
