import "package:sesori_auth/sesori_auth.dart";

import "../../repositories/models/bridge_settings_result.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading() extends BridgeSettingsState;

final class const BridgeSettingsDisconnected() extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({required this.error, required this.validationBounds}) extends BridgeSettingsState {
  final ApiError error;
  final PullRequestRefreshSettingsBounds? validationBounds;
}

sealed class const BridgeSettingsReady({
    required this.pullRequestRefreshIntervalSeconds,
    required this.pullRequestRefreshMutation,
  }) extends BridgeSettingsState {
  final int pullRequestRefreshIntervalSeconds;
  final PullRequestRefreshMutationState pullRequestRefreshMutation;

  PullRequestRefreshSettingsBounds? get validationBounds => pullRequestRefreshMutation.validationBounds;
}

final class const BridgeSettingsReadyFull({
    required super.pullRequestRefreshIntervalSeconds,
    required super.pullRequestRefreshMutation,
    required this.yoloEnabled,
    required this.yoloMutation,
  }) extends BridgeSettingsReady {
  final bool yoloEnabled;
  final YoloMutationState yoloMutation;
}

final class const BridgeSettingsReadyLegacyPartial({
    required super.pullRequestRefreshIntervalSeconds,
    required super.pullRequestRefreshMutation,
  }) extends BridgeSettingsReady;

sealed class const PullRequestRefreshMutationState() {
  PullRequestRefreshSettingsBounds? get validationBounds;
}

final class const PullRequestRefreshMutationIdle({required this.validationBounds}) extends PullRequestRefreshMutationState {
  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class const PullRequestRefreshMutationInProgress({required this.validationBounds}) extends PullRequestRefreshMutationState {
  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class const PullRequestRefreshMutationRangeRejected({required this.bounds}) extends PullRequestRefreshMutationState {
  final PullRequestRefreshSettingsBounds bounds;

  @override
  PullRequestRefreshSettingsBounds get validationBounds => bounds;
}

final class const PullRequestRefreshMutationFailed({required this.error, required this.validationBounds}) extends PullRequestRefreshMutationState {
  final PullRequestRefreshMutationError error;

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class const PullRequestRefreshMutationUncertain({required this.refreshError, required this.validationBounds}) extends PullRequestRefreshMutationState {
  final ApiError refreshError;

  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

final class const PullRequestRefreshMutationUnsupported({required this.validationBounds}) extends PullRequestRefreshMutationState {
  @override
  final PullRequestRefreshSettingsBounds? validationBounds;
}

sealed class const PullRequestRefreshMutationError();

final class const PullRequestRefreshInvalidInput() extends PullRequestRefreshMutationError;

final class const PullRequestRefreshRequestFailed({required this.error}) extends PullRequestRefreshMutationError {
  final ApiError error;
}

sealed class const YoloMutationState();

final class const YoloMutationIdle() extends YoloMutationState;

final class const YoloMutationInProgress() extends YoloMutationState;

final class const YoloMutationFailed({required this.error}) extends YoloMutationState {
  final ApiError error;
}

final class const YoloMutationUncertain({required this.refreshError}) extends YoloMutationState {
  final ApiError refreshError;
}

final class const YoloMutationUnsupported() extends YoloMutationState;
