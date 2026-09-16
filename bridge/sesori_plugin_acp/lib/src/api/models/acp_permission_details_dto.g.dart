// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acp_permission_details_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AcpPermissionDetailsDto _$AcpPermissionDetailsDtoFromJson(Map json) =>
    _AcpPermissionDetailsDto(
      kind: $enumDecodeNullable(
        _$AcpPermissionToolKindEnumMap,
        json['kind'],
        unknownValue: AcpPermissionToolKind.unknown,
      ),
      locations:
          (json['locations'] as List<dynamic>?)
              ?.map(
                (e) => AcpPermissionLocationDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      content:
          (json['content'] as List<dynamic>?)
              ?.map(
                (e) => AcpPermissionContentDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );

const _$AcpPermissionToolKindEnumMap = {
  AcpPermissionToolKind.edit: 'edit',
  AcpPermissionToolKind.delete: 'delete',
  AcpPermissionToolKind.move: 'move',
  AcpPermissionToolKind.fetch: 'fetch',
  AcpPermissionToolKind.unknown: 'unknown',
};

_AcpPermissionLocationDto _$AcpPermissionLocationDtoFromJson(Map json) =>
    _AcpPermissionLocationDto(path: json['path'] as String);

AcpPermissionDiffDto _$AcpPermissionDiffDtoFromJson(Map json) =>
    AcpPermissionDiffDto(
      path: json['path'] as String,
      oldText: json['oldText'] as String?,
      $type: json['type'] as String?,
    );

AcpPermissionStandardContentDto _$AcpPermissionStandardContentDtoFromJson(
  Map json,
) => AcpPermissionStandardContentDto(
  content: AcpPermissionResourceDto.fromJson(
    Map<String, dynamic>.from(json['content'] as Map),
  ),
  $type: json['type'] as String?,
);

AcpPermissionUnknownContentDto _$AcpPermissionUnknownContentDtoFromJson(
  Map json,
) => AcpPermissionUnknownContentDto($type: json['type'] as String?);

AcpPermissionResourceLinkDto _$AcpPermissionResourceLinkDtoFromJson(Map json) =>
    AcpPermissionResourceLinkDto(
      uri: json['uri'] as String,
      $type: json['type'] as String?,
    );

AcpPermissionUnknownResourceDto _$AcpPermissionUnknownResourceDtoFromJson(
  Map json,
) => AcpPermissionUnknownResourceDto($type: json['type'] as String?);
