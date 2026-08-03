import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/pull_request_refresh_settings_result.dart";
import "../repositories/pull_request_refresh_settings_repository.dart";

@lazySingleton
class PullRequestRefreshSettingsService {
  PullRequestRefreshSettingsService({required PullRequestRefreshSettingsRepository repository})
    : _repository = repository;

  final PullRequestRefreshSettingsRepository _repository;

  Future<PullRequestRefreshSettingsLoadResult> load() => _repository.load();

  Future<PullRequestRefreshSettingsMutationResult> update({
    required PullRequestRefreshSettingsRequest request,
  }) => _repository.update(request: request);

  PullRequestRefreshSettingsUpdatePlan planUpdate({
    required String input,
    required PullRequestRefreshSettingsBounds? bounds,
  }) {
    final intervalSeconds = int.tryParse(input.trim());
    if (intervalSeconds == null || (bounds != null && !bounds.includes(intervalSeconds: intervalSeconds))) {
      return const PullRequestRefreshSettingsUpdateInvalid();
    }
    return PullRequestRefreshSettingsUpdateRequest(
      request: PullRequestRefreshSettingsRequest(intervalSeconds: intervalSeconds),
    );
  }
}

sealed class PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdatePlan();
}

final class PullRequestRefreshSettingsUpdateRequest extends PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdateRequest({required this.request});

  final PullRequestRefreshSettingsRequest request;
}

final class PullRequestRefreshSettingsUpdateInvalid extends PullRequestRefreshSettingsUpdatePlan {
  const PullRequestRefreshSettingsUpdateInvalid();
}
