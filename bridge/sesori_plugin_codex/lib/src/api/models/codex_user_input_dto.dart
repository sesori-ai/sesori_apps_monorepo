import "package:freezed_annotation/freezed_annotation.dart";

part "codex_user_input_dto.freezed.dart";
part "codex_user_input_dto.g.dart";

enum CodexAgentMessageDelivery() {
  async,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexUserInputParamsDto with _$CodexUserInputParamsDto {
  const factory({
    required List<CodexUserInputQuestionDto> questions,
  }) = _CodexUserInputParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexUserInputParamsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexUserInputQuestionDto with _$CodexUserInputQuestionDto {
  const factory({
    required String id,
    required String header,
    required String question,
    required List<CodexUserInputOptionDto>? options,
    @Default(false) bool isOther,
    @Default(false) bool isSecret,
  }) = _CodexUserInputQuestionDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexUserInputQuestionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexUserInputOptionDto with _$CodexUserInputOptionDto {
  const factory({
    required String label,
    required String description,
  }) = _CodexUserInputOptionDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexUserInputOptionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexQuestionItemParamsDto with _$CodexQuestionItemParamsDto {
  const factory({
    required String threadId,
    required CodexQuestionItemDto item,
  }) = _CodexQuestionItemParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexQuestionItemParamsDtoFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class CodexQuestionItemDto with _$CodexQuestionItemDto {
  @FreezedUnionValue("agentMessage")
  const factory agentMessage({
    required String id,
    @JsonKey(unknownEnumValue: CodexAgentMessageDelivery.unknown) required CodexAgentMessageDelivery? delivery,
    required List<CodexAsyncUserInputQuestionDto>? questions,
  }) = CodexAgentQuestionItemDto;

  const factory unknown() = CodexUnknownQuestionItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexQuestionItemDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexAsyncUserInputQuestionDto with _$CodexAsyncUserInputQuestionDto {
  const factory({
    required String title,
    required List<String>? options,
  }) = _CodexAsyncUserInputQuestionDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexAsyncUserInputQuestionDtoFromJson(json);
}
