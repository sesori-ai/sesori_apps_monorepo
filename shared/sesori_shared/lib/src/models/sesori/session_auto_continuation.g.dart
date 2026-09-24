// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_auto_continuation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionAutoContinuationView _$SessionAutoContinuationViewFromJson(Map json) =>
    _SessionAutoContinuationView(
      enabled: json['enabled'] as bool,
      availability: $enumDecode(
        _$AutoContinuationAvailabilityEnumMap,
        json['availability'],
        unknownValue: AutoContinuationAvailability.unknown,
      ),
      status: SessionAutoContinuationStatus.fromJson(
        Map<String, dynamic>.from(json['status'] as Map),
      ),
    );

Map<String, dynamic> _$SessionAutoContinuationViewToJson(
  _SessionAutoContinuationView instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'availability': _$AutoContinuationAvailabilityEnumMap[instance.availability]!,
  'status': instance.status.toJson(),
};

const _$AutoContinuationAvailabilityEnumMap = {
  AutoContinuationAvailability.conditional: 'conditional',
  AutoContinuationAvailability.unavailable: 'unavailable',
  AutoContinuationAvailability.unknown: 'unknown',
};

SessionAutoContinuationIdle _$SessionAutoContinuationIdleFromJson(Map json) =>
    SessionAutoContinuationIdle($type: json['kind'] as String?);

Map<String, dynamic> _$SessionAutoContinuationIdleToJson(
  SessionAutoContinuationIdle instance,
) => <String, dynamic>{'kind': instance.$type};

SessionAutoContinuationResetKnown _$SessionAutoContinuationResetKnownFromJson(
  Map json,
) => SessionAutoContinuationResetKnown(
  resetAt: (json['resetAt'] as num).toInt(),
  continueAt: (json['continueAt'] as num).toInt(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionAutoContinuationResetKnownToJson(
  SessionAutoContinuationResetKnown instance,
) => <String, dynamic>{
  'resetAt': instance.resetAt,
  'continueAt': instance.continueAt,
  'kind': instance.$type,
};

SessionAutoContinuationResetUnknown
_$SessionAutoContinuationResetUnknownFromJson(Map json) =>
    SessionAutoContinuationResetUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$SessionAutoContinuationResetUnknownToJson(
  SessionAutoContinuationResetUnknown instance,
) => <String, dynamic>{'kind': instance.$type};

SessionAutoContinuationPaused _$SessionAutoContinuationPausedFromJson(
  Map json,
) => SessionAutoContinuationPaused(
  resetAt: (json['resetAt'] as num).toInt(),
  continueAt: (json['continueAt'] as num).toInt(),
  reason: $enumDecode(
    _$AutoContinuationPauseReasonEnumMap,
    json['reason'],
    unknownValue: AutoContinuationPauseReason.unknown,
  ),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionAutoContinuationPausedToJson(
  SessionAutoContinuationPaused instance,
) => <String, dynamic>{
  'resetAt': instance.resetAt,
  'continueAt': instance.continueAt,
  'reason': _$AutoContinuationPauseReasonEnumMap[instance.reason]!,
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

SessionAutoContinuationAttemptUnconfirmed
_$SessionAutoContinuationAttemptUnconfirmedFromJson(Map json) =>
    SessionAutoContinuationAttemptUnconfirmed($type: json['kind'] as String?);

Map<String, dynamic> _$SessionAutoContinuationAttemptUnconfirmedToJson(
  SessionAutoContinuationAttemptUnconfirmed instance,
) => <String, dynamic>{'kind': instance.$type};

SessionAutoContinuationSubmitted _$SessionAutoContinuationSubmittedFromJson(
  Map json,
) => SessionAutoContinuationSubmitted(
  acceptedAt: (json['acceptedAt'] as num).toInt(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionAutoContinuationSubmittedToJson(
  SessionAutoContinuationSubmitted instance,
) => <String, dynamic>{
  'acceptedAt': instance.acceptedAt,
  'kind': instance.$type,
};

SessionAutoContinuationSubmissionFailed
_$SessionAutoContinuationSubmissionFailedFromJson(Map json) =>
    SessionAutoContinuationSubmissionFailed(
      reason: $enumDecode(
        _$AutoContinuationFailureReasonEnumMap,
        json['reason'],
        unknownValue: AutoContinuationFailureReason.unknown,
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionAutoContinuationSubmissionFailedToJson(
  SessionAutoContinuationSubmissionFailed instance,
) => <String, dynamic>{
  'reason': _$AutoContinuationFailureReasonEnumMap[instance.reason]!,
  'kind': instance.$type,
};

const _$AutoContinuationFailureReasonEnumMap = {
  AutoContinuationFailureReason.submissionRejected: 'submissionRejected',
  AutoContinuationFailureReason.unknown: 'unknown',
};

SessionAutoContinuationUnknown _$SessionAutoContinuationUnknownFromJson(
  Map json,
) => SessionAutoContinuationUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$SessionAutoContinuationUnknownToJson(
  SessionAutoContinuationUnknown instance,
) => <String, dynamic>{'kind': instance.$type};
