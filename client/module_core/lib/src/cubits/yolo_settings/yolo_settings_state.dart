import "package:sesori_auth/sesori_auth.dart";

sealed class YoloSettingsState {
  const YoloSettingsState();
}

final class YoloSettingsLoading extends YoloSettingsState {
  const YoloSettingsLoading();
}

final class YoloSettingsDisconnected extends YoloSettingsState {
  const YoloSettingsDisconnected();
}

final class YoloSettingsUnsupported extends YoloSettingsState {
  const YoloSettingsUnsupported();
}

final class YoloSettingsFailure extends YoloSettingsState {
  const YoloSettingsFailure({required this.error});

  final ApiError error;
}

final class YoloSettingsUncertain extends YoloSettingsState {
  const YoloSettingsUncertain({required this.refreshError});

  final ApiError refreshError;
}

final class YoloSettingsReady extends YoloSettingsState {
  const YoloSettingsReady({required this.enabled, required this.mutation});

  final bool enabled;
  final YoloSettingsMutationState mutation;
}

sealed class YoloSettingsMutationState {
  const YoloSettingsMutationState();
}

final class YoloSettingsMutationIdle extends YoloSettingsMutationState {
  const YoloSettingsMutationIdle();
}

final class YoloSettingsMutationInProgress extends YoloSettingsMutationState {
  const YoloSettingsMutationInProgress();
}

final class YoloSettingsMutationFailed extends YoloSettingsMutationState {
  const YoloSettingsMutationFailed({required this.error});

  final ApiError error;
}
