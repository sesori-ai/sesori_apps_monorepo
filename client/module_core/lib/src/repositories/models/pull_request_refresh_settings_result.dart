import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class PullRequestRefreshSettingsLoadResult {
  const PullRequestRefreshSettingsLoadResult();
}

final class PullRequestRefreshSettingsLoadSupported extends PullRequestRefreshSettingsLoadResult {
  const PullRequestRefreshSettingsLoadSupported({required this.response});

  final PullRequestRefreshSettingsResponse response;
}

final class PullRequestRefreshSettingsLoadUnsupported extends PullRequestRefreshSettingsLoadResult {
  const PullRequestRefreshSettingsLoadUnsupported();
}

final class PullRequestRefreshSettingsLoadFailure extends PullRequestRefreshSettingsLoadResult {
  const PullRequestRefreshSettingsLoadFailure({required this.error});

  final ApiError error;
}

sealed class PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationResult();
}

final class PullRequestRefreshSettingsMutationCommitted extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationCommitted({required this.response});

  final PullRequestRefreshSettingsResponse response;
}

final class PullRequestRefreshSettingsMutationUnsupported extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationUnsupported();
}

final class PullRequestRefreshSettingsMutationRejected extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationRejected({required this.error});

  final PullRequestRefreshSettingsErrorResponse error;
}

final class PullRequestRefreshSettingsMutationUncertain extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationUncertain();
}

final class PullRequestRefreshSettingsMutationFailure extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationFailure({required this.error});

  final ApiError error;
}
