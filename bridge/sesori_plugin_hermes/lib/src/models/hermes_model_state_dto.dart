import "package:freezed_annotation/freezed_annotation.dart";

part "hermes_model_state_dto.freezed.dart";
part "hermes_model_state_dto.g.dart";

@freezed
sealed class HermesModelInfoDto with _$HermesModelInfoDto {
  const factory({
    @Default("") String modelId,
    @Default("") String name,
    required String? description,
  }) = _HermesModelInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesModelInfoDtoFromJson(json);
}

@freezed
sealed class HermesSessionModelStateDto with _$HermesSessionModelStateDto {
  const factory({
    @Default(<HermesModelInfoDto>[]) List<HermesModelInfoDto> availableModels,
    @Default("") String currentModelId,
  }) = _HermesSessionModelStateDto;

  factory fromJson(Map<String, dynamic> json) => _$HermesSessionModelStateDtoFromJson(json);
}
