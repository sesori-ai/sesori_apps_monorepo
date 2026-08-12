import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsLoadResult();

final class const BridgeSettingsLoadSupported({required final BridgeSettingsResponse response})
    extends BridgeSettingsLoadResult;

final class const BridgeSettingsLoadLegacyPartial({
  required final PullRequestRefreshSettingsResponse pullRequestRefresh,
}) extends BridgeSettingsLoadResult;

final class const BridgeSettingsLoadUnsupported() extends BridgeSettingsLoadResult;

final class const BridgeSettingsLoadFailure({required final ApiError error}) extends BridgeSettingsLoadResult;

sealed class const PullRequestRefreshSettingsMutationResult();

final class const PullRequestRefreshSettingsMutationCommitted({
  required final PullRequestRefreshSettingsResponse response,
}) extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationUnsupported() extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationRejected({required final PullRequestRefreshSettingsBounds bounds})
    extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationUncertain() extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationFailure({required final ApiError error})
    extends PullRequestRefreshSettingsMutationResult;

sealed class const YoloSettingsMutationResult();

final class const YoloSettingsMutationCommitted({required final YoloSettingsResponse response})
    extends YoloSettingsMutationResult;

final class const YoloSettingsMutationUnsupported() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationUncertain() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationFailure({required final ApiError error}) extends YoloSettingsMutationResult;

final class const PullRequestRefreshSettingsBounds._({
  required final int minimumIntervalSeconds,
  required final int maximumIntervalSeconds,
}) {
  factory({
    required int minimumIntervalSeconds,
    required int maximumIntervalSeconds,
  }) {
    if (minimumIntervalSeconds > maximumIntervalSeconds) {
      throw ArgumentError.value(
        (minimumIntervalSeconds, maximumIntervalSeconds),
        "intervalBounds",
        "The minimum interval must not exceed the maximum interval",
      );
    }
    return PullRequestRefreshSettingsBounds._(
      minimumIntervalSeconds: minimumIntervalSeconds,
      maximumIntervalSeconds: maximumIntervalSeconds,
    );
  }

  bool includes({required int intervalSeconds}) {
    return intervalSeconds >= minimumIntervalSeconds && intervalSeconds <= maximumIntervalSeconds;
  }
}
