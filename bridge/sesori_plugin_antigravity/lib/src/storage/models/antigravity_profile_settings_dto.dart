import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_profile_settings_dto.freezed.dart";
part "antigravity_profile_settings_dto.g.dart";

const _settingsOptions = Freezed(fromJson: false, toJson: true, copyWith: false, equal: false, toStringOverride: false);

enum AntigravityProfileAuthType() {
  @JsonValue("oauth-personal")
  personalOauth,
}

/// Non-secret settings only. Google owns token contents; Sesori never decodes them.
@_settingsOptions
sealed class AntigravityProfileSettingsDto with _$AntigravityProfileSettingsDto {
  const factory({required AntigravityProfileAuthDto auth}) = _AntigravityProfileSettingsDto;
}

@_settingsOptions
sealed class AntigravityProfileAuthDto with _$AntigravityProfileAuthDto {
  const factory({required AntigravityProfileAuthType type}) = _AntigravityProfileAuthDto;
}
