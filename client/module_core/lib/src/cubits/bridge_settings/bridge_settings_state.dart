import "package:sesori_auth/sesori_auth.dart";

import "../../repositories/models/bridge_settings_result.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading() extends BridgeSettingsState;

final class const BridgeSettingsDisconnected() extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({
  required final ApiError error,
  required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends BridgeSettingsState;

sealed class const BridgeSettingsReady({
  required final int pullRequestRefreshIntervalSeconds,
  required final PullRequestRefreshMutationState pullRequestRefreshMutation,
}) extends BridgeSettingsState {
  PullRequestRefreshSettingsBounds? get validationBounds => pullRequestRefreshMutation.validationBounds;
}

final class const BridgeSettingsReadyFull({
  required super.pullRequestRefreshIntervalSeconds,
  required super.pullRequestRefreshMutation,
  required final bool yoloEnabled,
  required final YoloMutationState yoloMutation,
}) extends BridgeSettingsReady;

final class const BridgeSettingsReadyLegacyPartial({
  required super.pullRequestRefreshIntervalSeconds,
  required super.pullRequestRefreshMutation,
}) extends BridgeSettingsReady;

sealed class const PullRequestRefreshMutationState() {
  PullRequestRefreshSettingsBounds? get validationBounds;
}

final class const PullRequestRefreshMutationIdle({
  @override required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends PullRequestRefreshMutationState;

final class const PullRequestRefreshMutationInProgress({
  @override required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends PullRequestRefreshMutationState;

final class const PullRequestRefreshMutationRangeRejected({required final PullRequestRefreshSettingsBounds bounds})
    extends PullRequestRefreshMutationState {
  @override
  PullRequestRefreshSettingsBounds get validationBounds => bounds;
}

final class const PullRequestRefreshMutationFailed({
  required final PullRequestRefreshMutationError error,
  @override required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends PullRequestRefreshMutationState;

final class const PullRequestRefreshMutationUncertain({
  required final ApiError refreshError,
  @override required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends PullRequestRefreshMutationState;

final class const PullRequestRefreshMutationUnsupported({
  @override required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends PullRequestRefreshMutationState;

sealed class const PullRequestRefreshMutationError();

final class const PullRequestRefreshInvalidInput() extends PullRequestRefreshMutationError;

final class const PullRequestRefreshRequestFailed({required final ApiError error})
    extends PullRequestRefreshMutationError;

sealed class const YoloMutationState();

final class const YoloMutationIdle() extends YoloMutationState;

final class const YoloMutationInProgress() extends YoloMutationState;

final class const YoloMutationFailed({required final ApiError error}) extends YoloMutationState;

final class const YoloMutationUncertain({required final ApiError refreshError}) extends YoloMutationState;

final class const YoloMutationUnsupported() extends YoloMutationState;
