// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_permission_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AntigravityPermissionRequestDto _$AntigravityPermissionRequestDtoFromJson(
  Map json,
) => $checkedCreate('_AntigravityPermissionRequestDto', json, ($checkedConvert) {
  final val = _AntigravityPermissionRequestDto(
    sessionId: $checkedConvert('sessionId', (v) => v as String),
    toolCall: $checkedConvert(
      'toolCall',
      (v) => AntigravityPermissionToolDto.fromJson(
        Map<String, dynamic>.from(v as Map),
      ),
    ),
    options: $checkedConvert('options', (v) => _optionsFromJson(v as List)),
  );
  return val;
});

_AntigravityPermissionToolDto _$AntigravityPermissionToolDtoFromJson(
  Map json,
) => $checkedCreate('_AntigravityPermissionToolDto', json, ($checkedConvert) {
  final val = _AntigravityPermissionToolDto(
    toolCallId: $checkedConvert('toolCallId', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecodeNullable(
        _$AntigravityPermissionToolKindEnumMap,
        v,
        unknownValue: AntigravityPermissionToolKind.unknown,
      ),
    ),
  );
  return val;
});

const _$AntigravityPermissionToolKindEnumMap = {
  AntigravityPermissionToolKind.read: 'read',
  AntigravityPermissionToolKind.edit: 'edit',
  AntigravityPermissionToolKind.delete: 'delete',
  AntigravityPermissionToolKind.move: 'move',
  AntigravityPermissionToolKind.search: 'search',
  AntigravityPermissionToolKind.execute: 'execute',
  AntigravityPermissionToolKind.think: 'think',
  AntigravityPermissionToolKind.fetch: 'fetch',
  AntigravityPermissionToolKind.other: 'other',
  AntigravityPermissionToolKind.unknown: 'unknown',
};

_AntigravityPermissionOptionDto _$AntigravityPermissionOptionDtoFromJson(
  Map json,
) => $checkedCreate('_AntigravityPermissionOptionDto', json, ($checkedConvert) {
  final val = _AntigravityPermissionOptionDto(
    optionId: $checkedConvert('optionId', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$AntigravityPermissionKindEnumMap,
        v,
        unknownValue: AntigravityPermissionKind.unknown,
      ),
    ),
    metadata: $checkedConvert(
      '_meta',
      (v) => v == null
          ? null
          : AntigravityPermissionMetadataDto.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
    ),
  );
  return val;
}, fieldKeyMap: const {'metadata': '_meta'});

const _$AntigravityPermissionKindEnumMap = {
  AntigravityPermissionKind.allowOnce: 'allow_once',
  AntigravityPermissionKind.allowAlways: 'allow_always',
  AntigravityPermissionKind.rejectOnce: 'reject_once',
  AntigravityPermissionKind.rejectAlways: 'reject_always',
  AntigravityPermissionKind.unknown: 'unknown',
};

_AntigravityPermissionMetadataDto _$AntigravityPermissionMetadataDtoFromJson(
  Map json,
) => $checkedCreate('_AntigravityPermissionMetadataDto', json, (
  $checkedConvert,
) {
  final val = _AntigravityPermissionMetadataDto(
    hasWarning: $checkedConvert(
      'agy.security.warning',
      (v) => v == null ? false : _warningPresent(v),
    ),
  );
  return val;
}, fieldKeyMap: const {'hasWarning': 'agy.security.warning'});
