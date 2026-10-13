// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_authentication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpAuthenticationAttempt _$McpAuthenticationAttemptFromJson(Map json) =>
    _McpAuthenticationAttempt(
      attemptId: json['attemptId'] as String,
      pluginId: json['pluginId'] as String,
      target: McpEntryTarget.serverFromJson(
        json['target'] as Map<String, dynamic>,
      ),
      cancellation: $enumDecode(
        _$McpAuthenticationCancellationEnumMap,
        json['cancellation'],
        unknownValue: McpAuthenticationCancellation.unknown,
      ),
    );

Map<String, dynamic> _$McpAuthenticationAttemptToJson(
  _McpAuthenticationAttempt instance,
) => <String, dynamic>{
  'attemptId': instance.attemptId,
  'pluginId': instance.pluginId,
  'target': instance.target.toJson(),
  'cancellation':
      _$McpAuthenticationCancellationEnumMap[instance.cancellation]!,
};

const _$McpAuthenticationCancellationEnumMap = {
  McpAuthenticationCancellation.unknown: 'unknown',
  McpAuthenticationCancellation.cancelable: 'cancelable',
  McpAuthenticationCancellation.nativeSettlement: 'nativeSettlement',
};

McpAuthenticationUnknown _$McpAuthenticationUnknownFromJson(Map json) =>
    McpAuthenticationUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpAuthenticationUnknownToJson(
  McpAuthenticationUnknown instance,
) => <String, dynamic>{'type': instance.$type};

McpAuthenticationIdle _$McpAuthenticationIdleFromJson(Map json) =>
    McpAuthenticationIdle($type: json['type'] as String?);

Map<String, dynamic> _$McpAuthenticationIdleToJson(
  McpAuthenticationIdle instance,
) => <String, dynamic>{'type': instance.$type};

McpAuthenticationStarting _$McpAuthenticationStartingFromJson(Map json) =>
    McpAuthenticationStarting(
      attempt: McpAuthenticationAttempt.fromJson(
        Map<String, dynamic>.from(json['attempt'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationStartingToJson(
  McpAuthenticationStarting instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'type': instance.$type,
};

McpAuthenticationCallbackChallenge _$McpAuthenticationCallbackChallengeFromJson(
  Map json,
) => McpAuthenticationCallbackChallenge(
  attempt: McpAuthenticationAttempt.fromJson(
    Map<String, dynamic>.from(json['attempt'] as Map),
  ),
  authorizationUrl: json['authorizationUrl'] as String,
  expectedCallbackUrl: json['expectedCallbackUrl'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpAuthenticationCallbackChallengeToJson(
  McpAuthenticationCallbackChallenge instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'authorizationUrl': instance.authorizationUrl,
  'expectedCallbackUrl': instance.expectedCallbackUrl,
  'type': instance.$type,
};

McpAuthenticationSettling _$McpAuthenticationSettlingFromJson(Map json) =>
    McpAuthenticationSettling(
      attempt: McpAuthenticationAttempt.fromJson(
        Map<String, dynamic>.from(json['attempt'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationSettlingToJson(
  McpAuthenticationSettling instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'type': instance.$type,
};

McpAuthenticationCompleted _$McpAuthenticationCompletedFromJson(Map json) =>
    McpAuthenticationCompleted(
      attempt: McpAuthenticationAttempt.fromJson(
        Map<String, dynamic>.from(json['attempt'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationCompletedToJson(
  McpAuthenticationCompleted instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'type': instance.$type,
};

McpAuthenticationFailed _$McpAuthenticationFailedFromJson(Map json) =>
    McpAuthenticationFailed(
      attempt: McpAuthenticationAttempt.fromJson(
        Map<String, dynamic>.from(json['attempt'] as Map),
      ),
      reason: $enumDecode(
        _$McpAuthenticationFailureReasonEnumMap,
        json['reason'],
        unknownValue: McpAuthenticationFailureReason.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationFailedToJson(
  McpAuthenticationFailed instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'reason': _$McpAuthenticationFailureReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$McpAuthenticationFailureReasonEnumMap = {
  McpAuthenticationFailureReason.unknown: 'unknown',
  McpAuthenticationFailureReason.nativeFailure: 'nativeFailure',
  McpAuthenticationFailureReason.declined: 'declined',
  McpAuthenticationFailureReason.expired: 'expired',
  McpAuthenticationFailureReason.nativeTrustRequired: 'nativeTrustRequired',
  McpAuthenticationFailureReason.interrupted: 'interrupted',
};

McpAuthenticationCancelled _$McpAuthenticationCancelledFromJson(Map json) =>
    McpAuthenticationCancelled(
      attempt: McpAuthenticationAttempt.fromJson(
        Map<String, dynamic>.from(json['attempt'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationCancelledToJson(
  McpAuthenticationCancelled instance,
) => <String, dynamic>{
  'attempt': instance.attempt.toJson(),
  'type': instance.$type,
};

_McpAuthenticationStartRequest _$McpAuthenticationStartRequestFromJson(
  Map json,
) => _McpAuthenticationStartRequest(
  pluginId: json['pluginId'] as String,
  target: McpEntryTarget.serverFromJson(json['target'] as Map<String, dynamic>),
);

Map<String, dynamic> _$McpAuthenticationStartRequestToJson(
  _McpAuthenticationStartRequest instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'target': instance.target.toJson(),
};

_McpAuthenticationContinueRequest _$McpAuthenticationContinueRequestFromJson(
  Map json,
) => _McpAuthenticationContinueRequest(
  attemptId: json['attemptId'] as String,
  callbackUrl: json['callbackUrl'] as String,
);

Map<String, dynamic> _$McpAuthenticationContinueRequestToJson(
  _McpAuthenticationContinueRequest instance,
) => <String, dynamic>{
  'attemptId': instance.attemptId,
  'callbackUrl': instance.callbackUrl,
};

_McpAuthenticationCancelRequest _$McpAuthenticationCancelRequestFromJson(
  Map json,
) => _McpAuthenticationCancelRequest(attemptId: json['attemptId'] as String);

Map<String, dynamic> _$McpAuthenticationCancelRequestToJson(
  _McpAuthenticationCancelRequest instance,
) => <String, dynamic>{'attemptId': instance.attemptId};

McpAuthenticationResultUnknown _$McpAuthenticationResultUnknownFromJson(
  Map json,
) => McpAuthenticationResultUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpAuthenticationResultUnknownToJson(
  McpAuthenticationResultUnknown instance,
) => <String, dynamic>{'type': instance.$type};

McpAuthenticationStateResult _$McpAuthenticationStateResultFromJson(Map json) =>
    McpAuthenticationStateResult(
      state: McpAuthenticationState.fromJson(
        Map<String, dynamic>.from(json['state'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationStateResultToJson(
  McpAuthenticationStateResult instance,
) => <String, dynamic>{
  'state': instance.state.toJson(),
  'type': instance.$type,
};

McpAuthenticationBusy _$McpAuthenticationBusyFromJson(Map json) =>
    McpAuthenticationBusy($type: json['type'] as String?);

Map<String, dynamic> _$McpAuthenticationBusyToJson(
  McpAuthenticationBusy instance,
) => <String, dynamic>{'type': instance.$type};

McpAuthenticationUnavailable _$McpAuthenticationUnavailableFromJson(Map json) =>
    McpAuthenticationUnavailable(
      reason: $enumDecode(
        _$McpAuthenticationUnavailableReasonEnumMap,
        json['reason'],
        unknownValue: McpAuthenticationUnavailableReason.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpAuthenticationUnavailableToJson(
  McpAuthenticationUnavailable instance,
) => <String, dynamic>{
  'reason': _$McpAuthenticationUnavailableReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$McpAuthenticationUnavailableReasonEnumMap = {
  McpAuthenticationUnavailableReason.unknown: 'unknown',
  McpAuthenticationUnavailableReason.unsupportedHarness: 'unsupportedHarness',
  McpAuthenticationUnavailableReason.unsupportedScope: 'unsupportedScope',
  McpAuthenticationUnavailableReason.liveSessionRequired: 'liveSessionRequired',
  McpAuthenticationUnavailableReason.pluginInactive: 'pluginInactive',
  McpAuthenticationUnavailableReason.targetNotFound: 'targetNotFound',
  McpAuthenticationUnavailableReason.nativeConfigurationRequired:
      'nativeConfigurationRequired',
  McpAuthenticationUnavailableReason.notSupported: 'notSupported',
  McpAuthenticationUnavailableReason.notImplemented: 'notImplemented',
  McpAuthenticationUnavailableReason.attemptNotFound: 'attemptNotFound',
  McpAuthenticationUnavailableReason.callbackRejected: 'callbackRejected',
  McpAuthenticationUnavailableReason.nativeCancellationUnavailable:
      'nativeCancellationUnavailable',
};
