// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GenericPermissionDetails _$GenericPermissionDetailsFromJson(Map json) =>
    GenericPermissionDetails($type: json['kind'] as String?);

Map<String, dynamic> _$GenericPermissionDetailsToJson(
  GenericPermissionDetails instance,
) => <String, dynamic>{'kind': instance.$type};

CommandPermissionDetails _$CommandPermissionDetailsFromJson(Map json) =>
    CommandPermissionDetails(
      command: json['command'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$CommandPermissionDetailsToJson(
  CommandPermissionDetails instance,
) => <String, dynamic>{'command': instance.command, 'kind': instance.$type};

FileChangesPermissionDetails _$FileChangesPermissionDetailsFromJson(Map json) =>
    FileChangesPermissionDetails(
      files: (json['files'] as List<dynamic>)
          .map(
            (e) => PermissionFile.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$FileChangesPermissionDetailsToJson(
  FileChangesPermissionDetails instance,
) => <String, dynamic>{
  'files': instance.files.map((e) => e.toJson()).toList(),
  'kind': instance.$type,
};

NetworkPermissionDetails _$NetworkPermissionDetailsFromJson(Map json) =>
    NetworkPermissionDetails(
      targets: (json['targets'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      command: json['command'] as String?,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$NetworkPermissionDetailsToJson(
  NetworkPermissionDetails instance,
) => <String, dynamic>{
  'targets': instance.targets,
  'command': ?instance.command,
  'kind': instance.$type,
};

_PermissionFile _$PermissionFileFromJson(Map json) => _PermissionFile(
  path: json['path'] as String,
  operation: $enumDecodeNullable(
    _$PermissionFileOperationEnumMap,
    json['operation'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
);

Map<String, dynamic> _$PermissionFileToJson(_PermissionFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'operation': ?_$PermissionFileOperationEnumMap[instance.operation],
    };

const _$PermissionFileOperationEnumMap = {
  PermissionFileOperation.create: 'create',
  PermissionFileOperation.write: 'write',
  PermissionFileOperation.delete: 'delete',
};
