// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_continuation_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionContinuationNone _$SessionContinuationNoneFromJson(Map json) =>
    SessionContinuationNone($type: json['kind'] as String?);

Map<String, dynamic> _$SessionContinuationNoneToJson(
  SessionContinuationNone instance,
) => <String, dynamic>{'kind': instance.$type};

SessionContinuationResetKnown _$SessionContinuationResetKnownFromJson(
  Map json,
) => SessionContinuationResetKnown(
  errorMessageId: json['errorMessageId'] as String,
  observedAt: DateTime.parse(json['observedAt'] as String),
  resetAt: DateTime.parse(json['resetAt'] as String),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionContinuationResetKnownToJson(
  SessionContinuationResetKnown instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'observedAt': instance.observedAt.toIso8601String(),
  'resetAt': instance.resetAt.toIso8601String(),
  'kind': instance.$type,
};

SessionContinuationResetUnknown _$SessionContinuationResetUnknownFromJson(
  Map json,
) => SessionContinuationResetUnknown(
  errorMessageId: json['errorMessageId'] as String,
  observedAt: DateTime.parse(json['observedAt'] as String),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionContinuationResetUnknownToJson(
  SessionContinuationResetUnknown instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'observedAt': instance.observedAt.toIso8601String(),
  'kind': instance.$type,
};

SessionContinuationPaused _$SessionContinuationPausedFromJson(Map json) =>
    SessionContinuationPaused(
      errorMessageId: json['errorMessageId'] as String,
      observedAt: DateTime.parse(json['observedAt'] as String),
      resetAt: DateTime.parse(json['resetAt'] as String),
      reason: $enumDecode(_$AutoContinuationPauseReasonEnumMap, json['reason']),
      recheckAt: DateTime.parse(json['recheckAt'] as String),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionContinuationPausedToJson(
  SessionContinuationPaused instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'observedAt': instance.observedAt.toIso8601String(),
  'resetAt': instance.resetAt.toIso8601String(),
  'reason': _$AutoContinuationPauseReasonEnumMap[instance.reason]!,
  'recheckAt': instance.recheckAt.toIso8601String(),
  'kind': instance.$type,
};

const _$AutoContinuationPauseReasonEnumMap = {
  AutoContinuationPauseReason.busy: 'busy',
  AutoContinuationPauseReason.retrying: 'retrying',
  AutoContinuationPauseReason.queued: 'queued',
  AutoContinuationPauseReason.awaitingInput: 'awaitingInput',
  AutoContinuationPauseReason.unavailable: 'unavailable',
  AutoContinuationPauseReason.historyUnavailable: 'historyUnavailable',
  AutoContinuationPauseReason.unknown: 'unknown',
};

SessionContinuationConsumed _$SessionContinuationConsumedFromJson(Map json) =>
    SessionContinuationConsumed(
      errorMessageId: json['errorMessageId'] as String,
      promptId: json['promptId'] as String,
      attemptedAt: DateTime.parse(json['attemptedAt'] as String),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionContinuationConsumedToJson(
  SessionContinuationConsumed instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'promptId': instance.promptId,
  'attemptedAt': instance.attemptedAt.toIso8601String(),
  'kind': instance.$type,
};

SessionContinuationSubmitted _$SessionContinuationSubmittedFromJson(Map json) =>
    SessionContinuationSubmitted(
      errorMessageId: json['errorMessageId'] as String,
      promptId: json['promptId'] as String,
      acceptedAt: DateTime.parse(json['acceptedAt'] as String),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionContinuationSubmittedToJson(
  SessionContinuationSubmitted instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'promptId': instance.promptId,
  'acceptedAt': instance.acceptedAt.toIso8601String(),
  'kind': instance.$type,
};

SessionContinuationCancelled _$SessionContinuationCancelledFromJson(Map json) =>
    SessionContinuationCancelled(
      errorMessageId: json['errorMessageId'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionContinuationCancelledToJson(
  SessionContinuationCancelled instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'kind': instance.$type,
};

SessionContinuationSubmissionFailed
_$SessionContinuationSubmissionFailedFromJson(Map json) =>
    SessionContinuationSubmissionFailed(
      errorMessageId: json['errorMessageId'] as String,
      reason: $enumDecode(
        _$AutoContinuationFailureReasonEnumMap,
        json['reason'],
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionContinuationSubmissionFailedToJson(
  SessionContinuationSubmissionFailed instance,
) => <String, dynamic>{
  'errorMessageId': instance.errorMessageId,
  'reason': _$AutoContinuationFailureReasonEnumMap[instance.reason]!,
  'kind': instance.$type,
};

const _$AutoContinuationFailureReasonEnumMap = {
  AutoContinuationFailureReason.submissionRejected: 'submissionRejected',
  AutoContinuationFailureReason.unknown: 'unknown',
};
