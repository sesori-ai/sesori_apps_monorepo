// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_continuation_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
SessionContinuationOutcome _$SessionContinuationOutcomeFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'none':
          return SessionContinuationNone.fromJson(
            json
          );
                case 'resetKnown':
          return SessionContinuationResetKnown.fromJson(
            json
          );
                case 'resetUnknown':
          return SessionContinuationResetUnknown.fromJson(
            json
          );
                case 'paused':
          return SessionContinuationPaused.fromJson(
            json
          );
                case 'consumed':
          return SessionContinuationConsumed.fromJson(
            json
          );
                case 'submitted':
          return SessionContinuationSubmitted.fromJson(
            json
          );
                case 'cancelled':
          return SessionContinuationCancelled.fromJson(
            json
          );
                case 'submissionFailed':
          return SessionContinuationSubmissionFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'SessionContinuationOutcome',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$SessionContinuationOutcome {



  /// Serializes this SessionContinuationOutcome to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationOutcome);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionContinuationOutcome()';
}


}





/// @nodoc
@JsonSerializable()

class SessionContinuationNone extends SessionContinuationOutcome {
  const SessionContinuationNone({ String? $type}): $type = $type ?? 'none',super._();
  factory SessionContinuationNone.fromJson(Map<String, dynamic> json) => _$SessionContinuationNoneFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationNoneToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationNone);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionContinuationOutcome.none()';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationResetKnown extends SessionContinuationOutcome {
  const SessionContinuationResetKnown({required this.errorMessageId, required this.observedAt, required this.resetAt,  String? $type}): $type = $type ?? 'resetKnown',super._();
  factory SessionContinuationResetKnown.fromJson(Map<String, dynamic> json) => _$SessionContinuationResetKnownFromJson(json);

 final  String errorMessageId;
 final  DateTime observedAt;
 final  DateTime resetAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationResetKnownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationResetKnown&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,observedAt,resetAt);
}

@override
String toString() {
    return 'SessionContinuationOutcome.resetKnown(errorMessageId: $errorMessageId, observedAt: $observedAt, resetAt: $resetAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationResetUnknown extends SessionContinuationOutcome {
  const SessionContinuationResetUnknown({required this.errorMessageId, required this.observedAt,  String? $type}): $type = $type ?? 'resetUnknown',super._();
  factory SessionContinuationResetUnknown.fromJson(Map<String, dynamic> json) => _$SessionContinuationResetUnknownFromJson(json);

 final  String errorMessageId;
 final  DateTime observedAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationResetUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationResetUnknown&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,observedAt);
}

@override
String toString() {
    return 'SessionContinuationOutcome.resetUnknown(errorMessageId: $errorMessageId, observedAt: $observedAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationPaused extends SessionContinuationOutcome {
  const SessionContinuationPaused({required this.errorMessageId, required this.observedAt, required this.resetAt, required this.reason, required this.recheckAt,  String? $type}): $type = $type ?? 'paused',super._();
  factory SessionContinuationPaused.fromJson(Map<String, dynamic> json) => _$SessionContinuationPausedFromJson(json);

 final  String errorMessageId;
 final  DateTime observedAt;
 final  DateTime resetAt;
 final  AutoContinuationPauseReason reason;
 final  DateTime recheckAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationPausedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationPaused&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.recheckAt, recheckAt) || other.recheckAt == recheckAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,observedAt,resetAt,reason,recheckAt);
}

@override
String toString() {
    return 'SessionContinuationOutcome.paused(errorMessageId: $errorMessageId, observedAt: $observedAt, resetAt: $resetAt, reason: $reason, recheckAt: $recheckAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationConsumed extends SessionContinuationOutcome {
  const SessionContinuationConsumed({required this.errorMessageId, required this.promptId, required this.attemptedAt,  String? $type}): $type = $type ?? 'consumed',super._();
  factory SessionContinuationConsumed.fromJson(Map<String, dynamic> json) => _$SessionContinuationConsumedFromJson(json);

 final  String errorMessageId;
 final  String promptId;
 final  DateTime attemptedAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationConsumedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationConsumed&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.attemptedAt, attemptedAt) || other.attemptedAt == attemptedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,promptId,attemptedAt);
}

@override
String toString() {
    return 'SessionContinuationOutcome.consumed(errorMessageId: $errorMessageId, promptId: $promptId, attemptedAt: $attemptedAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationSubmitted extends SessionContinuationOutcome {
  const SessionContinuationSubmitted({required this.errorMessageId, required this.promptId, required this.acceptedAt,  String? $type}): $type = $type ?? 'submitted',super._();
  factory SessionContinuationSubmitted.fromJson(Map<String, dynamic> json) => _$SessionContinuationSubmittedFromJson(json);

 final  String errorMessageId;
 final  String promptId;
 final  DateTime acceptedAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationSubmittedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationSubmitted&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,promptId,acceptedAt);
}

@override
String toString() {
    return 'SessionContinuationOutcome.submitted(errorMessageId: $errorMessageId, promptId: $promptId, acceptedAt: $acceptedAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationCancelled extends SessionContinuationOutcome {
  const SessionContinuationCancelled({required this.errorMessageId,  String? $type}): $type = $type ?? 'cancelled',super._();
  factory SessionContinuationCancelled.fromJson(Map<String, dynamic> json) => _$SessionContinuationCancelledFromJson(json);

 final  String errorMessageId;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationCancelledToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationCancelled&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId);
}

@override
String toString() {
    return 'SessionContinuationOutcome.cancelled(errorMessageId: $errorMessageId)';
}


}




/// @nodoc
@JsonSerializable()

class SessionContinuationSubmissionFailed extends SessionContinuationOutcome {
  const SessionContinuationSubmissionFailed({required this.errorMessageId, required this.reason,  String? $type}): $type = $type ?? 'submissionFailed',super._();
  factory SessionContinuationSubmissionFailed.fromJson(Map<String, dynamic> json) => _$SessionContinuationSubmissionFailedFromJson(json);

 final  String errorMessageId;
 final  AutoContinuationFailureReason reason;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionContinuationSubmissionFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionContinuationSubmissionFailed&&(identical(other.errorMessageId, errorMessageId) || other.errorMessageId == errorMessageId)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,errorMessageId,reason);
}

@override
String toString() {
    return 'SessionContinuationOutcome.submissionFailed(errorMessageId: $errorMessageId, reason: $reason)';
}


}




// dart format on
