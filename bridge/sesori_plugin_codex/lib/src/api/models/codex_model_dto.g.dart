// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_model_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexModelListResponseDto _$CodexModelListResponseDtoFromJson(Map json) =>
    _CodexModelListResponseDto(
      data: const CodexModelListConverter().fromJson(json['data']),
      nextCursor: json['nextCursor'] as String?,
    );

_CodexModelDto _$CodexModelDtoFromJson(Map json) => _CodexModelDto(
  id: json['id'] as String?,
  displayName: json['displayName'] as String?,
  hidden: json['hidden'] as bool?,
  supportedReasoningEfforts: const CodexReasoningEffortListConverter().fromJson(
    json['supportedReasoningEfforts'],
  ),
  defaultReasoningEffort: json['defaultReasoningEffort'] as String?,
  isDefault: json['isDefault'] as bool?,
);

_CodexReasoningEffortOptionDto _$CodexReasoningEffortOptionDtoFromJson(
  Map json,
) => _CodexReasoningEffortOptionDto(
  reasoningEffort: json['reasoningEffort'] as String?,
  description: json['description'] as String?,
);
