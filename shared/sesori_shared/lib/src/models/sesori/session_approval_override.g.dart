// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_approval_override.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetSessionApprovalOverrideRequest _$SetSessionApprovalOverrideRequestFromJson(
  Map json,
) => _SetSessionApprovalOverrideRequest(
  sessionId: json['sessionId'] as String,
  approvalOverride: $enumDecodeNullable(
    _$SessionApprovalModeEnumMap,
    json['approvalOverride'],
  ),
);

Map<String, dynamic> _$SetSessionApprovalOverrideRequestToJson(
  _SetSessionApprovalOverrideRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'approvalOverride': ?_$SessionApprovalModeEnumMap[instance.approvalOverride],
};

const _$SessionApprovalModeEnumMap = {
  SessionApprovalMode.ask: 'ask',
  SessionApprovalMode.yolo: 'yolo',
};

_SessionApprovalOverrideErrorResponse
_$SessionApprovalOverrideErrorResponseFromJson(Map json) =>
    _SessionApprovalOverrideErrorResponse(
      code: $enumDecode(
        _$SessionApprovalOverrideErrorCodeEnumMap,
        json['code'],
        unknownValue: SessionApprovalOverrideErrorCode.unknown,
      ),
    );

Map<String, dynamic> _$SessionApprovalOverrideErrorResponseToJson(
  _SessionApprovalOverrideErrorResponse instance,
) => <String, dynamic>{
  'code': _$SessionApprovalOverrideErrorCodeEnumMap[instance.code]!,
};

const _$SessionApprovalOverrideErrorCodeEnumMap = {
  SessionApprovalOverrideErrorCode.sessionNotFound: 'sessionNotFound',
  SessionApprovalOverrideErrorCode.unknown: 'unknown',
};
