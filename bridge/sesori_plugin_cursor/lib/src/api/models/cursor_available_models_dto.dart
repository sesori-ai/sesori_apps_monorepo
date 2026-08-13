import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_available_models_dto.freezed.dart";
part "cursor_available_models_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CursorAvailableModelsDto with _$CursorAvailableModelsDto {
  const factory({
    @Default(<CursorAvailableModelDto>[]) List<CursorAvailableModelDto> models,
  }) = _CursorAvailableModelsDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorAvailableModelsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorAvailableModelDto with _$CursorAvailableModelDto {
  const factory({
    required String value,
    required String? name,
    @Default(<CursorModelConfigOptionDto>[]) List<CursorModelConfigOptionDto> configOptions,
  }) = _CursorAvailableModelDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorAvailableModelDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorModelConfigOptionDto with _$CursorModelConfigOptionDto {
  const factory({
    required String id,
    required String? name,
    required String? description,
    required String? category,
    required String? currentValue,
    @Default(<CursorConfigOptionValueDto>[]) List<CursorConfigOptionValueDto> options,
  }) = _CursorModelConfigOptionDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorModelConfigOptionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CursorConfigOptionValueDto with _$CursorConfigOptionValueDto {
  const factory({
    required String value,
    required String? name,
    required String? description,
  }) = _CursorConfigOptionValueDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorConfigOptionValueDtoFromJson(json);
}
