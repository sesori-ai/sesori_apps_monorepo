import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class BridgeSettingsLoadResult {
  const BridgeSettingsLoadResult();
}

final class BridgeSettingsLoadSupported extends BridgeSettingsLoadResult {
  const BridgeSettingsLoadSupported({required this.response});

  final BridgeSettingsResponse response;
}

final class BridgeSettingsLoadLegacyPartial extends BridgeSettingsLoadResult {
  const BridgeSettingsLoadLegacyPartial({required this.pullRequestRefresh});

  final PullRequestRefreshSettingsResponse pullRequestRefresh;
}

final class BridgeSettingsLoadUnsupported extends BridgeSettingsLoadResult {
  const BridgeSettingsLoadUnsupported();
}

final class BridgeSettingsLoadFailure extends BridgeSettingsLoadResult {
  const BridgeSettingsLoadFailure({required this.error});

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
  const PullRequestRefreshSettingsMutationRejected({required this.bounds});

  final PullRequestRefreshSettingsBounds bounds;
}

final class PullRequestRefreshSettingsMutationUncertain extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationUncertain();
}

final class PullRequestRefreshSettingsMutationFailure extends PullRequestRefreshSettingsMutationResult {
  const PullRequestRefreshSettingsMutationFailure({required this.error});

  final ApiError error;
}

sealed class YoloSettingsMutationResult {
  const YoloSettingsMutationResult();
}

final class YoloSettingsMutationCommitted extends YoloSettingsMutationResult {
  const YoloSettingsMutationCommitted({required this.response});

  final YoloSettingsResponse response;
}

final class YoloSettingsMutationUnsupported extends YoloSettingsMutationResult {
  const YoloSettingsMutationUnsupported();
}

final class YoloSettingsMutationUncertain extends YoloSettingsMutationResult {
  const YoloSettingsMutationUncertain();
}

final class YoloSettingsMutationFailure extends YoloSettingsMutationResult {
  const YoloSettingsMutationFailure({required this.error});

  final ApiError error;
}

final class PullRequestRefreshSettingsBounds {
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

  const PullRequestRefreshSettingsBounds._({
    required this.minimumIntervalSeconds,
    required this.maximumIntervalSeconds,
  });

  final int minimumIntervalSeconds;
  final int maximumIntervalSeconds;

  bool includes({required int intervalSeconds}) {
    return intervalSeconds >= minimumIntervalSeconds && intervalSeconds <= maximumIntervalSeconds;
  }
}
