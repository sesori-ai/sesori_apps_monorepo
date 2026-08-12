import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsLoadResult();

final class const BridgeSettingsLoadSupported({required this.response}) extends BridgeSettingsLoadResult {
  final BridgeSettingsResponse response;
}

final class const BridgeSettingsLoadLegacyPartial({required this.pullRequestRefresh}) extends BridgeSettingsLoadResult {
  final PullRequestRefreshSettingsResponse pullRequestRefresh;
}

final class const BridgeSettingsLoadUnsupported() extends BridgeSettingsLoadResult;

final class const BridgeSettingsLoadFailure({required this.error}) extends BridgeSettingsLoadResult {
  final ApiError error;
}

sealed class const PullRequestRefreshSettingsMutationResult();

final class const PullRequestRefreshSettingsMutationCommitted({required this.response}) extends PullRequestRefreshSettingsMutationResult {
  final PullRequestRefreshSettingsResponse response;
}

final class const PullRequestRefreshSettingsMutationUnsupported() extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationRejected({required this.bounds}) extends PullRequestRefreshSettingsMutationResult {
  final PullRequestRefreshSettingsBounds bounds;
}

final class const PullRequestRefreshSettingsMutationUncertain() extends PullRequestRefreshSettingsMutationResult;

final class const PullRequestRefreshSettingsMutationFailure({required this.error}) extends PullRequestRefreshSettingsMutationResult {
  final ApiError error;
}

sealed class const YoloSettingsMutationResult();

final class const YoloSettingsMutationCommitted({required this.response}) extends YoloSettingsMutationResult {
  final YoloSettingsResponse response;
}

final class const YoloSettingsMutationUnsupported() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationUncertain() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationFailure({required this.error}) extends YoloSettingsMutationResult {
  final ApiError error;
}

final class const PullRequestRefreshSettingsBounds._({
    required this.minimumIntervalSeconds,
    required this.maximumIntervalSeconds,
  }) {
  factory PullRequestRefreshSettingsBounds({
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

  final int minimumIntervalSeconds;
  final int maximumIntervalSeconds;

  bool includes({required int intervalSeconds}) {
    return intervalSeconds >= minimumIntervalSeconds && intervalSeconds <= maximumIntervalSeconds;
  }
}
