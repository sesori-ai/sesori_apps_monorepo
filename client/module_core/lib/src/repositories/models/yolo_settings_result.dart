import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class YoloSettingsLoadResult {
  const YoloSettingsLoadResult();
}

final class YoloSettingsLoadSupported extends YoloSettingsLoadResult {
  const YoloSettingsLoadSupported({required this.response});

  final YoloSettingsResponse response;
}

final class YoloSettingsLoadUnsupported extends YoloSettingsLoadResult {
  const YoloSettingsLoadUnsupported();
}

final class YoloSettingsLoadFailure extends YoloSettingsLoadResult {
  const YoloSettingsLoadFailure({required this.error});

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
