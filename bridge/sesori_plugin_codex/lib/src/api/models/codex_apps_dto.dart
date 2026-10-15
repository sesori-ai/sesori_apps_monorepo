import "package:freezed_annotation/freezed_annotation.dart";

part "codex_apps_dto.freezed.dart";
part "codex_apps_dto.g.dart";

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexAppsPageDto with _$CodexAppsPageDto {
  const factory({required List<CodexAppInfoDto> data, required String? nextCursor}) = _CodexAppsPageDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexAppsPageDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexAppInfoDto with _$CodexAppInfoDto {
  const factory({
    required String id,
    required String name,
    required String? description,
    @Default(false) bool isAccessible,
    @Default(true) bool isEnabled,
  }) = _CodexAppInfoDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexAppInfoDtoFromJson(json);
}
