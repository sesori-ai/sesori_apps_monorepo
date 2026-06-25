// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_ownership_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexOwnershipRecord _$CodexOwnershipRecordFromJson(Map json) =>
    _CodexOwnershipRecord(
      ownerSessionId: json['ownerSessionId'] as String,
      codexPid: (json['codexPid'] as num).toInt(),
      codexStartMarker: json['codexStartMarker'] as String?,
      codexExecutablePath: json['codexExecutablePath'] as String,
      codexCommand: json['codexCommand'] as String,
      codexArgs: (json['codexArgs'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      port: (json['port'] as num).toInt(),
      bridgePid: (json['bridgePid'] as num).toInt(),
      bridgeStartMarker: json['bridgeStartMarker'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      status: $enumDecode(_$CodexOwnershipStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$CodexOwnershipRecordToJson(
  _CodexOwnershipRecord instance,
) => <String, dynamic>{
  'ownerSessionId': instance.ownerSessionId,
  'codexPid': instance.codexPid,
  'codexStartMarker': instance.codexStartMarker,
  'codexExecutablePath': instance.codexExecutablePath,
  'codexCommand': instance.codexCommand,
  'codexArgs': instance.codexArgs,
  'port': instance.port,
  'bridgePid': instance.bridgePid,
  'bridgeStartMarker': instance.bridgeStartMarker,
  'startedAt': instance.startedAt.toIso8601String(),
  'status': _$CodexOwnershipStatusEnumMap[instance.status]!,
};

const _$CodexOwnershipStatusEnumMap = {
  CodexOwnershipStatus.starting: 'starting',
  CodexOwnershipStatus.ready: 'ready',
  CodexOwnershipStatus.stopping: 'stopping',
};
