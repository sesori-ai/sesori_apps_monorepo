// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_archived_rejection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionArchivedRejection _$SessionArchivedRejectionFromJson(Map json) =>
    _SessionArchivedRejection(
      sessionId: json['sessionId'] as String,
      reason: $enumDecode(_$SessionArchivedReasonEnumMap, json['reason']),
    );

Map<String, dynamic> _$SessionArchivedRejectionToJson(
  _SessionArchivedRejection instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'reason': _$SessionArchivedReasonEnumMap[instance.reason]!,
};

const _$SessionArchivedReasonEnumMap = {
  SessionArchivedReason.archivedReadOnly: 'archived_read_only',
};
