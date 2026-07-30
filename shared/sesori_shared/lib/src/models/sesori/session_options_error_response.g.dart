// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_options_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionOptionsErrorResponse _$SessionOptionsErrorResponseFromJson(Map json) =>
    _SessionOptionsErrorResponse(
      code: $enumDecode(
        _$SessionOptionsErrorCodeEnumMap,
        json['code'],
        unknownValue: SessionOptionsErrorCode.unknown,
      ),
    );

Map<String, dynamic> _$SessionOptionsErrorResponseToJson(
  _SessionOptionsErrorResponse instance,
) => <String, dynamic>{
  'code': _$SessionOptionsErrorCodeEnumMap[instance.code]!,
};

const _$SessionOptionsErrorCodeEnumMap = {
  SessionOptionsErrorCode.cacheUnavailable: 'cacheUnavailable',
  SessionOptionsErrorCode.projectNotFound: 'projectNotFound',
  SessionOptionsErrorCode.refreshFailedRetained: 'refreshFailedRetained',
  SessionOptionsErrorCode.refreshFailedUnavailable: 'refreshFailedUnavailable',
  SessionOptionsErrorCode.unknown: 'unknown',
};
