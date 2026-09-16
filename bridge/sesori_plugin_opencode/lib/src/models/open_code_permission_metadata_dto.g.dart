// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_permission_metadata_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodePermissionMetadataDto _$OpenCodePermissionMetadataDtoFromJson(
  Map json,
) => _OpenCodePermissionMetadataDto(
  command: json['command'] as String?,
  filepath: json['filepath'] as String?,
  url: json['url'] as String?,
  files:
      (json['files'] as List<dynamic>?)
          ?.map(
            (e) => OpenCodePermissionFileDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const [],
);

_OpenCodePermissionFileDto _$OpenCodePermissionFileDtoFromJson(Map json) =>
    _OpenCodePermissionFileDto(
      filePath: json['filePath'] as String,
      type: $enumDecode(
        _$OpenCodePermissionFileTypeEnumMap,
        json['type'],
        unknownValue: OpenCodePermissionFileType.unknown,
      ),
      movePath: json['movePath'] as String?,
    );

const _$OpenCodePermissionFileTypeEnumMap = {
  OpenCodePermissionFileType.add: 'add',
  OpenCodePermissionFileType.update: 'update',
  OpenCodePermissionFileType.delete: 'delete',
  OpenCodePermissionFileType.move: 'move',
  OpenCodePermissionFileType.unknown: 'unknown',
};
