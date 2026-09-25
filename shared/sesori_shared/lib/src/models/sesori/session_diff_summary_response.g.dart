// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_diff_summary_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionDiffSummaryResponse _$SessionDiffSummaryResponseFromJson(Map json) =>
    _SessionDiffSummaryResponse(
      additions: (json['additions'] as num).toInt(),
      deletions: (json['deletions'] as num).toInt(),
    );

Map<String, dynamic> _$SessionDiffSummaryResponseToJson(
  _SessionDiffSummaryResponse instance,
) => <String, dynamic>{
  'additions': instance.additions,
  'deletions': instance.deletions,
};

_SessionDiffSummaryErrorResponse _$SessionDiffSummaryErrorResponseFromJson(
  Map json,
) => _SessionDiffSummaryErrorResponse(
  code: $enumDecode(
    _$SessionDiffSummaryErrorCodeEnumMap,
    json['code'],
    unknownValue: SessionDiffSummaryErrorCode.unknown,
  ),
);

Map<String, dynamic> _$SessionDiffSummaryErrorResponseToJson(
  _SessionDiffSummaryErrorResponse instance,
) => <String, dynamic>{
  'code': _$SessionDiffSummaryErrorCodeEnumMap[instance.code]!,
};

const _$SessionDiffSummaryErrorCodeEnumMap = {
  SessionDiffSummaryErrorCode.sessionNotFound: 'sessionNotFound',
  SessionDiffSummaryErrorCode.unknown: 'unknown',
};
