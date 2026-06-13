// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_start_intent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RuntimeStartIntent _$RuntimeStartIntentFromJson(Map<String, dynamic> json) =>
    _RuntimeStartIntent(
      ownerSessionId: json['ownerSessionId'] as String,
      port: (json['port'] as num).toInt(),
      bridgePid: (json['bridgePid'] as num).toInt(),
      bridgeStartMarker: json['bridgeStartMarker'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );

Map<String, dynamic> _$RuntimeStartIntentToJson(_RuntimeStartIntent instance) =>
    <String, dynamic>{
      'ownerSessionId': instance.ownerSessionId,
      'port': instance.port,
      'bridgePid': instance.bridgePid,
      'bridgeStartMarker': instance.bridgeStartMarker,
      'recordedAt': instance.recordedAt.toIso8601String(),
    };
