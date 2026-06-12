// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_ownership_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodeOwnershipRecord _$OpenCodeOwnershipRecordFromJson(Map json) =>
    _OpenCodeOwnershipRecord(
      ownerSessionId: json['ownerSessionId'] as String,
      openCodePid: (json['openCodePid'] as num).toInt(),
      openCodeStartMarker: json['openCodeStartMarker'] as String?,
      openCodeExecutablePath: json['openCodeExecutablePath'] as String,
      openCodeCommand: json['openCodeCommand'] as String,
      openCodeArgs: (json['openCodeArgs'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      port: (json['port'] as num).toInt(),
      bridgePid: (json['bridgePid'] as num).toInt(),
      bridgeStartMarker: json['bridgeStartMarker'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      status: $enumDecode(_$OpenCodeOwnershipStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$OpenCodeOwnershipRecordToJson(
  _OpenCodeOwnershipRecord instance,
) => <String, dynamic>{
  'ownerSessionId': instance.ownerSessionId,
  'openCodePid': instance.openCodePid,
  'openCodeStartMarker': instance.openCodeStartMarker,
  'openCodeExecutablePath': instance.openCodeExecutablePath,
  'openCodeCommand': instance.openCodeCommand,
  'openCodeArgs': instance.openCodeArgs,
  'port': instance.port,
  'bridgePid': instance.bridgePid,
  'bridgeStartMarker': instance.bridgeStartMarker,
  'startedAt': instance.startedAt.toIso8601String(),
  'status': _$OpenCodeOwnershipStatusEnumMap[instance.status]!,
};

const _$OpenCodeOwnershipStatusEnumMap = {
  OpenCodeOwnershipStatus.starting: 'starting',
  OpenCodeOwnershipStatus.ready: 'ready',
  OpenCodeOwnershipStatus.stopping: 'stopping',
};
