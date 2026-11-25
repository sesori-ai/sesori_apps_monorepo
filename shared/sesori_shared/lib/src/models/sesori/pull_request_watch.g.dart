// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_watch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionPullRequestWatch _$SessionPullRequestWatchFromJson(Map json) =>
    _SessionPullRequestWatch(
      repository: json['repository'] as String,
      number: (json['number'] as num).toInt(),
      title: json['title'] as String,
      url: json['url'] as String,
      autoMerge: json['autoMerge'] as bool,
      status: PullRequestWatchStatus.fromJson(
        Map<String, dynamic>.from(json['status'] as Map),
      ),
    );

Map<String, dynamic> _$SessionPullRequestWatchToJson(
  _SessionPullRequestWatch instance,
) => <String, dynamic>{
  'repository': instance.repository,
  'number': instance.number,
  'title': instance.title,
  'url': instance.url,
  'autoMerge': instance.autoMerge,
  'status': instance.status.toJson(),
};

PullRequestWatchStatusUnknown _$PullRequestWatchStatusUnknownFromJson(
  Map json,
) => PullRequestWatchStatusUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$PullRequestWatchStatusUnknownToJson(
  PullRequestWatchStatusUnknown instance,
) => <String, dynamic>{'kind': instance.$type};

PullRequestWatchStatusNeedsYou _$PullRequestWatchStatusNeedsYouFromJson(
  Map json,
) => PullRequestWatchStatusNeedsYou(
  reasons: (json['reasons'] as List<dynamic>)
      .map(
        (e) => $enumDecode(
          _$PullRequestWatchNeedEnumMap,
          e,
          unknownValue: PullRequestWatchNeed.unknown,
        ),
      )
      .toList(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$PullRequestWatchStatusNeedsYouToJson(
  PullRequestWatchStatusNeedsYou instance,
) => <String, dynamic>{
  'reasons': instance.reasons
      .map((e) => _$PullRequestWatchNeedEnumMap[e]!)
      .toList(),
  'kind': instance.$type,
};

const _$PullRequestWatchNeedEnumMap = {
  PullRequestWatchNeed.unknown: 'unknown',
  PullRequestWatchNeed.ciFailing: 'ciFailing',
  PullRequestWatchNeed.conflict: 'conflict',
  PullRequestWatchNeed.newReviewComments: 'newReviewComments',
  PullRequestWatchNeed.readyWithoutAutoMerge: 'readyWithoutAutoMerge',
};

PullRequestWatchStatusWaiting _$PullRequestWatchStatusWaitingFromJson(
  Map json,
) => PullRequestWatchStatusWaiting($type: json['kind'] as String?);

Map<String, dynamic> _$PullRequestWatchStatusWaitingToJson(
  PullRequestWatchStatusWaiting instance,
) => <String, dynamic>{'kind': instance.$type};

PullRequestWatchStatusReady _$PullRequestWatchStatusReadyFromJson(Map json) =>
    PullRequestWatchStatusReady($type: json['kind'] as String?);

Map<String, dynamic> _$PullRequestWatchStatusReadyToJson(
  PullRequestWatchStatusReady instance,
) => <String, dynamic>{'kind': instance.$type};

PullRequestWatchStatusMerged _$PullRequestWatchStatusMergedFromJson(Map json) =>
    PullRequestWatchStatusMerged(
      mergedAt: (json['mergedAt'] as num).toInt(),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$PullRequestWatchStatusMergedToJson(
  PullRequestWatchStatusMerged instance,
) => <String, dynamic>{'mergedAt': instance.mergedAt, 'kind': instance.$type};

_PullRequestWatchListResponse _$PullRequestWatchListResponseFromJson(
  Map json,
) => _PullRequestWatchListResponse(
  watches: (json['watches'] as List<dynamic>)
      .map(
        (e) => PullRequestWatchListItem.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
);

Map<String, dynamic> _$PullRequestWatchListResponseToJson(
  _PullRequestWatchListResponse instance,
) => <String, dynamic>{
  'watches': instance.watches.map((e) => e.toJson()).toList(),
};

_PullRequestWatchListItem _$PullRequestWatchListItemFromJson(Map json) =>
    _PullRequestWatchListItem(
      sessionId: json['sessionId'] as String,
      sessionTitle: json['sessionTitle'] as String?,
      projectId: json['projectId'] as String,
      watch: SessionPullRequestWatch.fromJson(
        Map<String, dynamic>.from(json['watch'] as Map),
      ),
    );

Map<String, dynamic> _$PullRequestWatchListItemToJson(
  _PullRequestWatchListItem instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'sessionTitle': ?instance.sessionTitle,
  'projectId': instance.projectId,
  'watch': instance.watch.toJson(),
};

_StopPullRequestWatchRequest _$StopPullRequestWatchRequestFromJson(Map json) =>
    _StopPullRequestWatchRequest(
      sessionId: json['sessionId'] as String,
      repository: json['repository'] as String,
      number: (json['number'] as num).toInt(),
    );

Map<String, dynamic> _$StopPullRequestWatchRequestToJson(
  _StopPullRequestWatchRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'repository': instance.repository,
  'number': instance.number,
};

_SetPullRequestWatchAutoMergeRequest
_$SetPullRequestWatchAutoMergeRequestFromJson(Map json) =>
    _SetPullRequestWatchAutoMergeRequest(
      sessionId: json['sessionId'] as String,
      repository: json['repository'] as String,
      number: (json['number'] as num).toInt(),
      enabled: json['enabled'] as bool,
    );

Map<String, dynamic> _$SetPullRequestWatchAutoMergeRequestToJson(
  _SetPullRequestWatchAutoMergeRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'repository': instance.repository,
  'number': instance.number,
  'enabled': instance.enabled,
};
