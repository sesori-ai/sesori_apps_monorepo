// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_side_question_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeSideQuestionResponseDto _$ClaudeSideQuestionResponseDtoFromJson(
  Map json,
) => _ClaudeSideQuestionResponseDto(
  response: json['response'] as String?,
  synthetic: json['synthetic'] as bool,
  refusalFallback: json['refusal_fallback'] == null
      ? null
      : ClaudeSideQuestionRefusalFallbackDto.fromJson(
          Map<String, dynamic>.from(json['refusal_fallback'] as Map),
        ),
);

_ClaudeSideQuestionRefusalFallbackDto
_$ClaudeSideQuestionRefusalFallbackDtoFromJson(Map json) =>
    _ClaudeSideQuestionRefusalFallbackDto(content: json['content'] as String?);
