// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_permission_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AntigravityPermissionRequestDto _$AntigravityPermissionRequestDtoFromJson(
  Map json,
) => _AntigravityPermissionRequestDto(
  sessionId: json['sessionId'] as String,
  toolCall: AntigravityPermissionToolDto.fromJson(
    Map<String, dynamic>.from(json['toolCall'] as Map),
  ),
  options: _optionsFromJson(json['options'] as List),
);

_AntigravityPermissionToolDto _$AntigravityPermissionToolDtoFromJson(
  Map json,
) => _AntigravityPermissionToolDto(
  toolCallId: json['toolCallId'] as String,
  title: json['title'] as String,
);

_AntigravityPermissionOptionDto _$AntigravityPermissionOptionDtoFromJson(
  Map json,
) => _AntigravityPermissionOptionDto(
  optionId: json['optionId'] as String,
  name: json['name'] as String,
  kind: $enumDecode(
    _$AntigravityPermissionKindEnumMap,
    json['kind'],
    unknownValue: AntigravityPermissionKind.unknown,
  ),
  metadata: json['_meta'] == null
      ? null
      : AntigravityPermissionMetadataDto.fromJson(
          Map<String, dynamic>.from(json['_meta'] as Map),
        ),
);

const _$AntigravityPermissionKindEnumMap = {
  AntigravityPermissionKind.allowOnce: 'allow_once',
  AntigravityPermissionKind.allowAlways: 'allow_always',
  AntigravityPermissionKind.rejectOnce: 'reject_once',
  AntigravityPermissionKind.rejectAlways: 'reject_always',
  AntigravityPermissionKind.unknown: 'unknown',
};

_AntigravityPermissionMetadataDto _$AntigravityPermissionMetadataDtoFromJson(
  Map json,
) => _AntigravityPermissionMetadataDto(
  hasWarning: json['agy.security.warning'] == null
      ? false
      : _warningPresent(json['agy.security.warning']),
);
