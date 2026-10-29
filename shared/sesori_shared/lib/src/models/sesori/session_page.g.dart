// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionPageRequest _$SessionPageRequestFromJson(Map json) =>
    _SessionPageRequest(
      mode: $enumDecode(_$SessionPageModeEnumMap, json['mode']),
      projectId: json['projectId'] as String?,
      query: json['query'] as String?,
      filter: $enumDecode(_$SessionPageFilterEnumMap, json['filter']),
      cursor: json['cursor'] as String?,
      limit: (json['limit'] as num).toInt(),
    );

Map<String, dynamic> _$SessionPageRequestToJson(_SessionPageRequest instance) =>
    <String, dynamic>{
      'mode': _$SessionPageModeEnumMap[instance.mode]!,
      'projectId': ?instance.projectId,
      'query': ?instance.query,
      'filter': _$SessionPageFilterEnumMap[instance.filter]!,
      'cursor': ?instance.cursor,
      'limit': instance.limit,
    };

const _$SessionPageModeEnumMap = {
  SessionPageMode.active: 'active',
  SessionPageMode.archived: 'archived',
};

const _$SessionPageFilterEnumMap = {
  SessionPageFilter.all: 'all',
  SessionPageFilter.running: 'running',
  SessionPageFilter.unread: 'unread',
};

_SessionPageResponse _$SessionPageResponseFromJson(Map json) =>
    _SessionPageResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => Session.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      counts: SessionPageCounts.fromJson(
        Map<String, dynamic>.from(json['counts'] as Map),
      ),
    );

Map<String, dynamic> _$SessionPageResponseToJson(
  _SessionPageResponse instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'nextCursor': ?instance.nextCursor,
  'counts': instance.counts.toJson(),
};

_SessionPageCounts _$SessionPageCountsFromJson(Map json) => _SessionPageCounts(
  all: (json['all'] as num).toInt(),
  running: (json['running'] as num).toInt(),
  unread: (json['unread'] as num).toInt(),
);

Map<String, dynamic> _$SessionPageCountsToJson(_SessionPageCounts instance) =>
    <String, dynamic>{
      'all': instance.all,
      'running': instance.running,
      'unread': instance.unread,
    };
