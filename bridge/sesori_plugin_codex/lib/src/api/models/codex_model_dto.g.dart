// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_model_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexModelListResponseDto _$CodexModelListResponseDtoFromJson(Map json) =>
    _CodexModelListResponseDto(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) => CodexModelDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );

_CodexModelDto _$CodexModelDtoFromJson(Map json) => _CodexModelDto(
  id: json['id'] as String?,
  displayName: json['displayName'] as String?,
  hidden: json['hidden'] as bool?,
  supportedReasoningEfforts:
      (json['supportedReasoningEfforts'] as List<dynamic>?)
          ?.map(
            (e) => CodexReasoningEffortOptionDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
  defaultReasoningEffort: json['defaultReasoningEffort'] as String?,
  isDefault: json['isDefault'] as bool?,
);

_CodexReasoningEffortOptionDto _$CodexReasoningEffortOptionDtoFromJson(
  Map json,
) => _CodexReasoningEffortOptionDto(
  reasoningEffort: json['reasoningEffort'] as String?,
  description: json['description'] as String?,
);
