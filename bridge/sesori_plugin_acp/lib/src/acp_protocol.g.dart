// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acp_protocol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AcpSessionInfo _$AcpSessionInfoFromJson(Map json) => _AcpSessionInfo(
  sessionId: json['sessionId'] as String? ?? "",
  cwd: json['cwd'] as String?,
  title: json['title'] as String?,
  updatedAtMs: const AcpTimestampMsConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$AcpSessionInfoToJson(_AcpSessionInfo instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'cwd': instance.cwd,
      'title': instance.title,
      'updatedAt': const AcpTimestampMsConverter().toJson(instance.updatedAtMs),
    };

_AcpSessionListResult _$AcpSessionListResultFromJson(Map json) =>
    _AcpSessionListResult(
      sessions:
          (json['sessions'] as List<dynamic>?)
              ?.map(
                (e) => AcpSessionInfo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <AcpSessionInfo>[],
      nextCursor: json['nextCursor'] as String?,
    );

Map<String, dynamic> _$AcpSessionListResultToJson(
  _AcpSessionListResult instance,
) => <String, dynamic>{
  'sessions': instance.sessions.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
};
