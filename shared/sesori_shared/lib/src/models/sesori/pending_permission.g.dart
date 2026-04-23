// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_permission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PendingPermissionResponse _$PendingPermissionResponseFromJson(Map json) =>
    _PendingPermissionResponse(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) =>
                PendingPermission.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$PendingPermissionResponseToJson(
  _PendingPermissionResponse instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

_PendingPermission _$PendingPermissionFromJson(Map json) => _PendingPermission(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  tool: json['tool'] as String,
  description: json['description'] as String,
);

Map<String, dynamic> _$PendingPermissionToJson(_PendingPermission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'tool': instance.tool,
      'description': instance.description,
    };
