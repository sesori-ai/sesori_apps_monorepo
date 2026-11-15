// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_branch_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionBranchErrorResponse _$SessionBranchErrorResponseFromJson(Map json) =>
    _SessionBranchErrorResponse(
      code: $enumDecode(
        _$SessionBranchErrorCodeEnumMap,
        json['code'],
        unknownValue: SessionBranchErrorCode.unknown,
      ),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$SessionBranchErrorResponseToJson(
  _SessionBranchErrorResponse instance,
) => <String, dynamic>{
  'code': _$SessionBranchErrorCodeEnumMap[instance.code]!,
  'message': ?instance.message,
};

const _$SessionBranchErrorCodeEnumMap = {
  SessionBranchErrorCode.sessionBusy: 'sessionBusy',
  SessionBranchErrorCode.branchPointUnavailable: 'branchPointUnavailable',
  SessionBranchErrorCode.nothingToFork: 'nothingToFork',
  SessionBranchErrorCode.staleSessionOptions: 'staleSessionOptions',
  SessionBranchErrorCode.refused: 'refused',
  SessionBranchErrorCode.unknown: 'unknown',
};
