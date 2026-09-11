// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'abort_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AbortSessionRequest _$AbortSessionRequestFromJson(Map json) =>
    _AbortSessionRequest(
      sessionId: json['sessionId'] as String,
      subAgents:
          $enumDecodeNullable(
            _$SessionAbortSubAgentPolicyEnumMap,
            json['subAgents'],
          ) ??
          SessionAbortSubAgentPolicy.stop,
      useAtomicStop: json['useAtomicStop'] as bool? ?? false,
    );

Map<String, dynamic> _$AbortSessionRequestToJson(
  _AbortSessionRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'subAgents': _$SessionAbortSubAgentPolicyEnumMap[instance.subAgents]!,
  'useAtomicStop': instance.useAtomicStop,
};

const _$SessionAbortSubAgentPolicyEnumMap = {
  SessionAbortSubAgentPolicy.confirm: 'confirm',
  SessionAbortSubAgentPolicy.keep: 'keep',
  SessionAbortSubAgentPolicy.stop: 'stop',
};

_SessionAbortResponse _$SessionAbortResponseFromJson(Map json) =>
    _SessionAbortResponse(
      subAgentsHandled: json['subAgentsHandled'] as bool? ?? false,
    );

Map<String, dynamic> _$SessionAbortResponseToJson(
  _SessionAbortResponse instance,
) => <String, dynamic>{'subAgentsHandled': instance.subAgentsHandled};

_SessionAbortRefusal _$SessionAbortRefusalFromJson(Map json) =>
    _SessionAbortRefusal(
      kind: $enumDecode(
        _$SessionAbortRefusalKindEnumMap,
        json['kind'],
        unknownValue: SessionAbortRefusalKind.unknownEnumValue,
      ),
      reason: $enumDecode(
        _$SessionAbortRefusalReasonEnumMap,
        json['reason'],
        unknownValue: SessionAbortRefusalReason.unknownEnumValue,
      ),
    );

Map<String, dynamic> _$SessionAbortRefusalToJson(
  _SessionAbortRefusal instance,
) => <String, dynamic>{
  'kind': _$SessionAbortRefusalKindEnumMap[instance.kind]!,
  'reason': _$SessionAbortRefusalReasonEnumMap[instance.reason]!,
};

const _$SessionAbortRefusalKindEnumMap = {
  SessionAbortRefusalKind.notPerformed: 'notPerformed',
  SessionAbortRefusalKind.unknownEnumValue: 'unknown',
};

const _$SessionAbortRefusalReasonEnumMap = {
  SessionAbortRefusalReason.residentWorkCompletionUnknown:
      'residentWorkCompletionUnknown',
  SessionAbortRefusalReason.unknownEnumValue: 'unknown',
};

_SessionAbortRejection _$SessionAbortRejectionFromJson(Map json) =>
    _SessionAbortRejection(
      runningSubAgentCount: (json['runningSubAgentCount'] as num).toInt(),
      mainAgentRunning: json['mainAgentRunning'] as bool,
      mainAgentOnlySupported: json['mainAgentOnlySupported'] as bool? ?? false,
    );

Map<String, dynamic> _$SessionAbortRejectionToJson(
  _SessionAbortRejection instance,
) => <String, dynamic>{
  'runningSubAgentCount': instance.runningSubAgentCount,
  'mainAgentRunning': instance.mainAgentRunning,
  'mainAgentOnlySupported': instance.mainAgentOnlySupported,
};
