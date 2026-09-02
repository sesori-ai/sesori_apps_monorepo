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
    );

Map<String, dynamic> _$AbortSessionRequestToJson(
  _AbortSessionRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'subAgents': _$SessionAbortSubAgentPolicyEnumMap[instance.subAgents]!,
};

const _$SessionAbortSubAgentPolicyEnumMap = {
  SessionAbortSubAgentPolicy.confirm: 'confirm',
  SessionAbortSubAgentPolicy.keep: 'keep',
  SessionAbortSubAgentPolicy.stop: 'stop',
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
