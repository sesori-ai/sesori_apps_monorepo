// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_permission_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginGenericPermissionDetailsToJson(
  PluginGenericPermissionDetails instance,
) => <String, dynamic>{'runtimeType': instance.$type};

Map<String, dynamic> _$PluginCommandPermissionDetailsToJson(
  PluginCommandPermissionDetails instance,
) => <String, dynamic>{
  'command': instance.command,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginFileChangesPermissionDetailsToJson(
  PluginFileChangesPermissionDetails instance,
) => <String, dynamic>{
  'files': instance.files.map((e) => e.toJson()).toList(),
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginNetworkPermissionDetailsToJson(
  PluginNetworkPermissionDetails instance,
) => <String, dynamic>{
  'targets': instance.targets,
  'command': ?instance.command,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginPermissionFileToJson(
  _PluginPermissionFile instance,
) => <String, dynamic>{
  'path': instance.path,
  'operation': ?_$PluginPermissionFileOperationEnumMap[instance.operation],
};

const _$PluginPermissionFileOperationEnumMap = {
  PluginPermissionFileOperation.create: 'create',
  PluginPermissionFileOperation.write: 'write',
  PluginPermissionFileOperation.delete: 'delete',
};
