import "package:sesori_auth/sesori_auth.dart";

import "../../repositories/models/bridge_settings_result.dart";

sealed class BridgeSettingsState {
  const BridgeSettingsState();
}

final class BridgeSettingsLoading extends BridgeSettingsState {
  const BridgeSettingsLoading();
}

final class BridgeSettingsDisconnected extends BridgeSettingsState {
  const BridgeSettingsDisconnected();
}

final class BridgeSettingsUnsupported extends BridgeSettingsState {
  const BridgeSettingsUnsupported();
}

final class BridgeSettingsFailure extends BridgeSettingsState {
  const BridgeSettingsFailure({required this.error, required this.validationBounds});

  final ApiError error;
  final PullRequestRefreshSettingsBounds? validationBounds;
}

sealed class BridgeSettingsReady extends BridgeSettingsState {
  const BridgeSettingsReady({
    required this.pullRequestRefreshIntervalSeconds,
    required this.pullRequestRefreshMutation,
  });

  final int pullRequestRefreshIntervalSeconds;
  final PullRequestRefreshMutationState pullRequestRefreshMutation;

  PullRequestRefreshSettingsBounds? get validationBounds => pullRequestRefreshMutation.validationBounds;
}

final class BridgeSettingsReadyFull extends BridgeSettingsReady {
  const BridgeSettingsReadyFull({
    required super.pullRequestRefreshIntervalSeconds,
    required super.pullRequestRefreshMutation,
    required this.yoloEnabled,
    required this.yoloMutation,
  });

  final bool yoloEnabled;
  final YoloMutationState yoloMutation;
}

final class BridgeSettingsReadyLegacyPartial extends BridgeSettingsReady {
  const BridgeSettingsReadyLegacyPartial({
    required super.pullRequestRefreshIntervalSeconds,
    required super.pullRequestRefreshMutation,
  });
}

sealed class PullRequestRefreshMutationState {
  const PullRequestRefreshMutationState();

  PullRequestRefreshSettingsBounds? get validationBounds;
}

final class PullRequestRefreshMutationIdle extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationIdle({required this.validationBounds});

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshMutationInProgress extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationInProgress({required this.validationBounds});

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshMutationRangeRejected extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationRangeRejected({required this.bounds});

  final PullRequestRefreshSettingsBounds bounds;

  @override
  PullRequestRefreshSettingsBounds get validationBounds => bounds;
}

final class PullRequestRefreshMutationFailed extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationFailed({required this.error, required this.validationBounds});

  final PullRequestRefreshMutationError error;

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshMutationUncertain extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationUncertain({required this.refreshError, required this.validationBounds});

  final ApiError refreshError;

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class PullRequestRefreshMutationUnsupported extends PullRequestRefreshMutationState {
  const PullRequestRefreshMutationUnsupported({required this.validationBounds});

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

sealed class PullRequestRefreshMutationError {
  const PullRequestRefreshMutationError();
}

final class PullRequestRefreshInvalidInput extends PullRequestRefreshMutationError {
  const PullRequestRefreshInvalidInput();
}

final class PullRequestRefreshRequestFailed extends PullRequestRefreshMutationError {
  const PullRequestRefreshRequestFailed({required this.error});

  final ApiError error;
}

sealed class YoloMutationState {
  const YoloMutationState();
}

final class YoloMutationIdle extends YoloMutationState {
  const YoloMutationIdle();
}

final class YoloMutationInProgress extends YoloMutationState {
  const YoloMutationInProgress();
}

final class YoloMutationFailed extends YoloMutationState {
  const YoloMutationFailed({required this.error});

  final ApiError error;
}

final class YoloMutationUncertain extends YoloMutationState {
  const YoloMutationUncertain({required this.refreshError});

  final ApiError refreshError;
}

final class YoloMutationUnsupported extends YoloMutationState {
  const YoloMutationUnsupported();
}
