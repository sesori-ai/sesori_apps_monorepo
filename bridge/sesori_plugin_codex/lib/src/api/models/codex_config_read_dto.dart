import "package:freezed_annotation/freezed_annotation.dart";

part "codex_config_read_dto.freezed.dart";
part "codex_config_read_dto.g.dart";

/// The part of a `config/read` response the bridge uses.
@Freezed(fromJson: true, toJson: false)
sealed class CodexConfigReadResponseDto with _$CodexConfigReadResponseDto {
  const factory({
    required CodexEffectiveConfigDto config,
  }) = _CodexConfigReadResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexConfigReadResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexEffectiveConfigDto with _$CodexEffectiveConfigDto {
  const factory({
    @JsonKey(name: "developer_instructions") required String? developerInstructions,
  }) = _CodexEffectiveConfigDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexEffectiveConfigDtoFromJson(json);
}
