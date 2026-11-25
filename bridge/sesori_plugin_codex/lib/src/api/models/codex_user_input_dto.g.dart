// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_user_input_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexUserInputParamsDto _$CodexUserInputParamsDtoFromJson(Map json) => _CodexUserInputParamsDto(
  questions: (json['questions'] as List<dynamic>)
      .map(
        (e) => CodexUserInputQuestionDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
);

_CodexUserInputQuestionDto _$CodexUserInputQuestionDtoFromJson(Map json) => _CodexUserInputQuestionDto(
  id: json['id'] as String,
  header: json['header'] as String,
  question: json['question'] as String,
  options: (json['options'] as List<dynamic>?)
      ?.map(
        (e) => CodexUserInputOptionDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
  isOther: json['isOther'] as bool? ?? false,
  isSecret: json['isSecret'] as bool? ?? false,
);

_CodexUserInputOptionDto _$CodexUserInputOptionDtoFromJson(Map json) => _CodexUserInputOptionDto(
  label: json['label'] as String,
  description: json['description'] as String,
);

_CodexQuestionItemParamsDto _$CodexQuestionItemParamsDtoFromJson(Map json) => _CodexQuestionItemParamsDto(
  threadId: json['threadId'] as String,
  item: CodexQuestionItemDto.fromJson(
    Map<String, dynamic>.from(json['item'] as Map),
  ),
);

CodexAgentQuestionItemDto _$CodexAgentQuestionItemDtoFromJson(Map json) => CodexAgentQuestionItemDto(
  id: json['id'] as String,
  delivery: $enumDecodeNullable(
    _$CodexAgentMessageDeliveryEnumMap,
    json['delivery'],
    unknownValue: CodexAgentMessageDelivery.unknown,
  ),
  questions: (json['questions'] as List<dynamic>?)
      ?.map(
        (e) => CodexAsyncUserInputQuestionDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
  $type: json['type'] as String?,
);

const _$CodexAgentMessageDeliveryEnumMap = {
  CodexAgentMessageDelivery.async: 'async',
  CodexAgentMessageDelivery.unknown: 'unknown',
};

CodexUnknownQuestionItemDto _$CodexUnknownQuestionItemDtoFromJson(Map json) =>
    CodexUnknownQuestionItemDto($type: json['type'] as String?);

_CodexAsyncUserInputQuestionDto _$CodexAsyncUserInputQuestionDtoFromJson(
  Map json,
) => _CodexAsyncUserInputQuestionDto(
  title: json['title'] as String,
  options: (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
);
