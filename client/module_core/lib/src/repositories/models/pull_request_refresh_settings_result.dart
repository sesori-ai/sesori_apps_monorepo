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
