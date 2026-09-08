import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_model_config_dto.freezed.dart";
part "antigravity_model_config_dto.g.dart";

const _options = Freezed(copyWith: false, equal: false, toStringOverride: false, toJson: false);

enum AntigravityConfigType() {
  select,
  unknown,
}

@_options
sealed class AntigravityModelConfigDto with _$AntigravityModelConfigDto {
  const factory({
    required String id,
    @JsonKey(unknownEnumValue: AntigravityConfigType.unknown) required AntigravityConfigType type,
    required String currentValue,
    @JsonKey(fromJson: _modelOptionsFromJson) required List<AntigravityModelOptionDto> options,
  }) = _AntigravityModelConfigDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityModelConfigDtoFromJson(json);
}

@_options
sealed class AntigravityModelOptionDto with _$AntigravityModelOptionDto {
  const factory({required String value, required String name}) = _AntigravityModelOptionDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityModelOptionDtoFromJson(json);
}

@_options
sealed class AntigravityModelGroupDto with _$AntigravityModelGroupDto {
  const factory({required List<AntigravityModelOptionDto> options}) = _AntigravityModelGroupDto;

  factory fromJson(Map<String, dynamic> json) => _$AntigravityModelGroupDtoFromJson(json);
}

// ACP select entries are either values or one-level groups, without a wire discriminator.
// ignore: no_slop_linter/prefer_specific_type, raw JSON union entries stop at generated value/group decoders
List<AntigravityModelOptionDto> _modelOptionsFromJson(List<dynamic> entries) => [
  // ignore: no_slop_linter/prefer_specific_type, generated DTO factories consume the external JSON object
  for (final entry in entries.cast<Map<String, dynamic>>())
    if (entry.containsKey("value"))
      AntigravityModelOptionDto.fromJson(entry)
    else
      ...AntigravityModelGroupDto.fromJson(entry).options,
];
