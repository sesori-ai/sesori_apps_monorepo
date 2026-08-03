import "package:sesori_auth/sesori_auth.dart";

import "../../repositories/models/pull_request_refresh_settings_result.dart";

sealed class PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsState();
}

final class PullRequestRefreshSettingsLoading extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsLoading();
}

final class PullRequestRefreshSettingsDisconnected extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsDisconnected();
}

final class PullRequestRefreshSettingsUnsupported extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsUnsupported();
}

final class PullRequestRefreshSettingsFailure extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsFailure({
    required this.error,
    required this.validationBounds,
  });

  final ApiError error;
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshSettingsUncertain extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsUncertain({
    required this.lastKnownIntervalSeconds,
    required this.refreshError,
    required this.validationBounds,
  });

  final int lastKnownIntervalSeconds;
  final ApiError refreshError;
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshSettingsReady extends PullRequestRefreshSettingsState {
  const PullRequestRefreshSettingsReady({required this.intervalSeconds, required this.mutation});

  final int intervalSeconds;
  final PullRequestRefreshSettingsMutationState mutation;

  PullRequestRefreshSettingsBounds? get validationBounds => mutation.validationBounds;
}

sealed class PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationState();

  PullRequestRefreshSettingsBounds? get validationBounds;
}

final class PullRequestRefreshSettingsMutationIdle extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationIdle({required this.validationBounds});

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshSettingsMutationInProgress extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationInProgress({required this.validationBounds});

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshSettingsMutationRangeRejected extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationRangeRejected({required this.bounds});

  final PullRequestRefreshSettingsBounds bounds;

  @override
  PullRequestRefreshSettingsBounds get validationBounds => bounds;
}

final class PullRequestRefreshSettingsMutationFailed extends PullRequestRefreshSettingsMutationState {
  const PullRequestRefreshSettingsMutationFailed({
    required this.error,
    required this.validationBounds,
  });

  final PullRequestRefreshSettingsMutationError error;

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

sealed class PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsMutationError();
}

final class PullRequestRefreshSettingsInvalidInput extends PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsInvalidInput();
}

final class PullRequestRefreshSettingsRequestFailed extends PullRequestRefreshSettingsMutationError {
  const PullRequestRefreshSettingsRequestFailed({required this.error});

  final ApiError error;
}
