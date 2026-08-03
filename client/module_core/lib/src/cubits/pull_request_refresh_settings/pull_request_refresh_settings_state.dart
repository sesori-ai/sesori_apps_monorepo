import "package:sesori_auth/sesori_auth.dart";

sealed class PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsState();
}

final class PullRequestRefreshSettingsLoading extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsLoading();
}

final class PullRequestRefreshSettingsUnsupported extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsUnsupported();
}

final class PullRequestRefreshSettingsFailure extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsFailure({required this.error});

  final ApiError error;
}

final class PullRequestRefreshSettingsUncertain extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsUncertain({
    required this.lastKnownIntervalSeconds,
    required this.refreshError,
  });

  final int lastKnownIntervalSeconds;
  final ApiError refreshError;
}

final class PullRequestRefreshSettingsReady extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsReady({required this.intervalSeconds, required this.mutation});

  final int intervalSeconds;
  final PullRequestRefreshSettingsMutationState mutation;
}

sealed class PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationState();
}

final class PullRequestRefreshSettingsMutationIdle extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationIdle();
}

final class PullRequestRefreshSettingsMutationInProgress extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationInProgress();
}

final class PullRequestRefreshSettingsMutationFailed extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationFailed({required this.error});

  final PullRequestRefreshSettingsMutationError error;
}

sealed class PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsMutationError();
}

final class PullRequestRefreshSettingsInvalidInput extends PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsInvalidInput();
}

final class PullRequestRefreshSettingsRejected extends PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsRejected({
    required this.minimumIntervalSeconds,
    required this.maximumIntervalSeconds,
  });

  final int minimumIntervalSeconds;
  final int maximumIntervalSeconds;
}

final class PullRequestRefreshSettingsRequestFailed extends PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsRequestFailed({required this.error});

  final ApiError error;
}
