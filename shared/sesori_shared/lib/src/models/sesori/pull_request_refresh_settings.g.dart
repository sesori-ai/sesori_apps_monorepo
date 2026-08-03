// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_refresh_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestRefreshSettingsRequest _$PullRequestRefreshSettingsRequestFromJson(
  Map json,
) => _PullRequestRefreshSettingsRequest(
  intervalSeconds: _strictIntFromJson(json['intervalSeconds']),
);

Map<String, dynamic> _$PullRequestRefreshSettingsRequestToJson(
  _PullRequestRefreshSettingsRequest instance,
) => <String, dynamic>{'intervalSeconds': instance.intervalSeconds};

_PullRequestRefreshSettingsResponse
_$PullRequestRefreshSettingsResponseFromJson(Map json) =>
    _PullRequestRefreshSettingsResponse(
      intervalSeconds: _strictIntFromJson(json['intervalSeconds']),
    );

Map<String, dynamic> _$PullRequestRefreshSettingsResponseToJson(
  _PullRequestRefreshSettingsResponse instance,
) => <String, dynamic>{'intervalSeconds': instance.intervalSeconds};

_PullRequestRefreshSettingsErrorResponse
_$PullRequestRefreshSettingsErrorResponseFromJson(
  Map json,
) => _PullRequestRefreshSettingsErrorResponse(
  code: $enumDecode(
    _$PullRequestRefreshSettingsErrorCodeEnumMap,
    json['code'],
    unknownValue: PullRequestRefreshSettingsErrorCode.unknown,
  ),
  minimumIntervalSeconds: _strictIntFromJson(json['minimumIntervalSeconds']),
  maximumIntervalSeconds: _strictIntFromJson(json['maximumIntervalSeconds']),
);

Map<String, dynamic> _$PullRequestRefreshSettingsErrorResponseToJson(
  _PullRequestRefreshSettingsErrorResponse instance,
) => <String, dynamic>{
  'code': _$PullRequestRefreshSettingsErrorCodeEnumMap[instance.code]!,
  'minimumIntervalSeconds': instance.minimumIntervalSeconds,
  'maximumIntervalSeconds': instance.maximumIntervalSeconds,
};

const _$PullRequestRefreshSettingsErrorCodeEnumMap = {
  PullRequestRefreshSettingsErrorCode.intervalOutOfRange: 'intervalOutOfRange',
  PullRequestRefreshSettingsErrorCode.unknown: 'unknown',
};
