import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_available_models_dto.freezed.dart";
part "cursor_available_models_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CursorAvailableModelsDto with _$CursorAvailableModelsDto {
  const factory CursorAvailableModelsDto({
    @Default(<CursorAvailableModelDto>[]) List<CursorAvailableModelDto> models,
  }) = _CursorAvailableModelsDto;

  factory CursorAvailableModelsDto.fromJson(Map<String, dynamic> json) => _$CursorAvailableModelsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorAvailableModelDto with _$CursorAvailableModelDto {
  const factory CursorAvailableModelDto({
    required String value,
    required String? name,
    @Default(<CursorModelConfigOptionDto>[]) List<CursorModelConfigOptionDto> configOptions,
  }) = _CursorAvailableModelDto;

  factory CursorAvailableModelDto.fromJson(Map<String, dynamic> json) => _$CursorAvailableModelDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorModelConfigOptionDto with _$CursorModelConfigOptionDto {
  const factory CursorModelConfigOptionDto({
    required String id,
    required String? name,
    required String? description,
    required String? category,
    required String? currentValue,
    @Default(<CursorConfigOptionValueDto>[]) List<CursorConfigOptionValueDto> options,
  }) = _CursorModelConfigOptionDto;

  factory CursorModelConfigOptionDto.fromJson(Map<String, dynamic> json) => _$CursorModelConfigOptionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorConfigOptionValueDto with _$CursorConfigOptionValueDto {
  const factory CursorConfigOptionValueDto({
    required String value,
    required String? name,
    required String? description,
  }) = _CursorConfigOptionValueDto;

  factory CursorConfigOptionValueDto.fromJson(Map<String, dynamic> json) => _$CursorConfigOptionValueDtoFromJson(json);
}
