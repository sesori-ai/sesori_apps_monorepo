// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_model_provider_error_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodexModelProviderMismatchDto _$CodexModelProviderMismatchDtoFromJson(
  Map json,
) => CodexModelProviderMismatchDto(
  modelProvider: json['modelProvider'] as String,
  currentModelProvider: json['currentModelProvider'] as String,
  $type: json['type'] as String?,
);

CodexModelProviderNotConfiguredDto _$CodexModelProviderNotConfiguredDtoFromJson(
  Map json,
) => CodexModelProviderNotConfiguredDto(
  modelProvider: json['modelProvider'] as String,
  $type: json['type'] as String?,
);

CodexModelProviderPolicyConflictDto
_$CodexModelProviderPolicyConflictDtoFromJson(Map json) =>
    CodexModelProviderPolicyConflictDto(
      modelProvider: json['modelProvider'] as String,
      requiredModelProvider: json['requiredModelProvider'] as String,
      $type: json['type'] as String?,
    );

CodexUnknownModelProviderErrorDto _$CodexUnknownModelProviderErrorDtoFromJson(
  Map json,
) => CodexUnknownModelProviderErrorDto($type: json['type'] as String?);
