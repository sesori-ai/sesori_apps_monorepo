// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_permission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PendingPermission _$PendingPermissionFromJson(Map json) => _PendingPermission(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  permission: json['permission'] as String,
);

Map<String, dynamic> _$PendingPermissionToJson(_PendingPermission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'permission': instance.permission,
    };
