// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_to_session_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendToSessionErrorResponse _$SendToSessionErrorResponseFromJson(Map json) =>
    _SendToSessionErrorResponse(
      code: $enumDecode(
        _$SendToSessionErrorCodeEnumMap,
        json['code'],
        unknownValue: SendToSessionErrorCode.unknown,
      ),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$SendToSessionErrorResponseToJson(
  _SendToSessionErrorResponse instance,
) => <String, dynamic>{
  'code': _$SendToSessionErrorCodeEnumMap[instance.code]!,
  'message': ?instance.message,
};

const _$SendToSessionErrorCodeEnumMap = {
  SendToSessionErrorCode.sameSession: 'sameSession',
  SendToSessionErrorCode.sourceArchived: 'sourceArchived',
  SendToSessionErrorCode.targetArchived: 'targetArchived',
  SendToSessionErrorCode.sourceNotRoot: 'sourceNotRoot',
  SendToSessionErrorCode.sourceBusy: 'sourceBusy',
  SendToSessionErrorCode.sourceAwaitingInput: 'sourceAwaitingInput',
  SendToSessionErrorCode.sourceUnavailable: 'sourceUnavailable',
  SendToSessionErrorCode.sourceOptionsUnavailable: 'sourceOptionsUnavailable',
  SendToSessionErrorCode.sourceEmpty: 'sourceEmpty',
  SendToSessionErrorCode.summaryStopped: 'summaryStopped',
  SendToSessionErrorCode.summaryFailed: 'summaryFailed',
  SendToSessionErrorCode.summaryTimedOut: 'summaryTimedOut',
  SendToSessionErrorCode.summaryMissing: 'summaryMissing',
  SendToSessionErrorCode.transcriptUnavailable: 'transcriptUnavailable',
  SendToSessionErrorCode.targetRefused: 'targetRefused',
  SendToSessionErrorCode.targetOptionsUnavailable: 'targetOptionsUnavailable',
  SendToSessionErrorCode.unknown: 'unknown',
};
