// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_auto_continuation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionAutoContinuationView {

 bool get enabled;@JsonKey(unknownEnumValue: AutoContinuationAvailability.unknown) AutoContinuationAvailability get availability; SessionAutoContinuationStatus get status;

  /// Serializes this SessionAutoContinuationView to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionAutoContinuationView;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationView&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.availability, _this.availability) || other.availability == _this.availability)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionAutoContinuationView;
  return Object.hash(runtimeType,_this.enabled,_this.availability,_this.status);
}

@override
String toString() {
  final _this = this as SessionAutoContinuationView;
  return 'SessionAutoContinuationView(enabled: ${_this.enabled}, availability: ${_this.availability}, status: ${_this.status})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionAutoContinuationView implements SessionAutoContinuationView {
  const _SessionAutoContinuationView({required this.enabled, @JsonKey(unknownEnumValue: AutoContinuationAvailability.unknown) required this.availability, required this.status});
  factory _SessionAutoContinuationView.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationViewFromJson(json);

@override final  bool enabled;
@override@JsonKey(unknownEnumValue: AutoContinuationAvailability.unknown) final  AutoContinuationAvailability availability;
@override final  SessionAutoContinuationStatus status;


@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationViewToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionAutoContinuationView&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled,availability,status);
}

@override
String toString() {
    return 'SessionAutoContinuationView(enabled: $enabled, availability: $availability, status: $status)';
}


}




SessionAutoContinuationStatus _$SessionAutoContinuationStatusFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'idle':
          return SessionAutoContinuationIdle.fromJson(
            json
          );
                case 'resetKnown':
          return SessionAutoContinuationResetKnown.fromJson(
            json
          );
                case 'resetUnknown':
          return SessionAutoContinuationResetUnknown.fromJson(
            json
          );
                case 'paused':
          return SessionAutoContinuationPaused.fromJson(
            json
          );
                case 'attemptUnconfirmed':
          return SessionAutoContinuationAttemptUnconfirmed.fromJson(
            json
          );
                case 'submitted':
          return SessionAutoContinuationSubmitted.fromJson(
            json
          );
                case 'submissionFailed':
          return SessionAutoContinuationSubmissionFailed.fromJson(
            json
          );
        
          default:
            return SessionAutoContinuationUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$SessionAutoContinuationStatus {



  /// Serializes this SessionAutoContinuationStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationStatus);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAutoContinuationStatus()';
}


}





/// @nodoc
@JsonSerializable()

class SessionAutoContinuationIdle implements SessionAutoContinuationStatus {
  const SessionAutoContinuationIdle({ String? $type}): $type = $type ?? 'idle';
  factory SessionAutoContinuationIdle.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationIdleFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationIdleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationIdle);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAutoContinuationStatus.idle()';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationResetKnown implements SessionAutoContinuationStatus {
  const SessionAutoContinuationResetKnown({required this.resetAt, required this.continueAt,  String? $type}): $type = $type ?? 'resetKnown';
  factory SessionAutoContinuationResetKnown.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationResetKnownFromJson(json);

 final  int resetAt;
 final  int continueAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationResetKnownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationResetKnown&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.continueAt, continueAt) || other.continueAt == continueAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,resetAt,continueAt);
}

@override
String toString() {
    return 'SessionAutoContinuationStatus.resetKnown(resetAt: $resetAt, continueAt: $continueAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationResetUnknown implements SessionAutoContinuationStatus {
  const SessionAutoContinuationResetUnknown({ String? $type}): $type = $type ?? 'resetUnknown';
  factory SessionAutoContinuationResetUnknown.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationResetUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationResetUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationResetUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAutoContinuationStatus.resetUnknown()';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationPaused implements SessionAutoContinuationStatus {
  const SessionAutoContinuationPaused({required this.resetAt, required this.continueAt, @JsonKey(unknownEnumValue: AutoContinuationPauseReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'paused';
  factory SessionAutoContinuationPaused.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationPausedFromJson(json);

 final  int resetAt;
 final  int continueAt;
@JsonKey(unknownEnumValue: AutoContinuationPauseReason.unknown) final  AutoContinuationPauseReason reason;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationPausedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationPaused&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.continueAt, continueAt) || other.continueAt == continueAt)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,resetAt,continueAt,reason);
}

@override
String toString() {
    return 'SessionAutoContinuationStatus.paused(resetAt: $resetAt, continueAt: $continueAt, reason: $reason)';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationAttemptUnconfirmed implements SessionAutoContinuationStatus {
  const SessionAutoContinuationAttemptUnconfirmed({ String? $type}): $type = $type ?? 'attemptUnconfirmed';
  factory SessionAutoContinuationAttemptUnconfirmed.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationAttemptUnconfirmedFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationAttemptUnconfirmedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationAttemptUnconfirmed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAutoContinuationStatus.attemptUnconfirmed()';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationSubmitted implements SessionAutoContinuationStatus {
  const SessionAutoContinuationSubmitted({required this.acceptedAt,  String? $type}): $type = $type ?? 'submitted';
  factory SessionAutoContinuationSubmitted.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationSubmittedFromJson(json);

 final  int acceptedAt;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationSubmittedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationSubmitted&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,acceptedAt);
}

@override
String toString() {
    return 'SessionAutoContinuationStatus.submitted(acceptedAt: $acceptedAt)';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationSubmissionFailed implements SessionAutoContinuationStatus {
  const SessionAutoContinuationSubmissionFailed({@JsonKey(unknownEnumValue: AutoContinuationFailureReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'submissionFailed';
  factory SessionAutoContinuationSubmissionFailed.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationSubmissionFailedFromJson(json);

@JsonKey(unknownEnumValue: AutoContinuationFailureReason.unknown) final  AutoContinuationFailureReason reason;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationSubmissionFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationSubmissionFailed&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'SessionAutoContinuationStatus.submissionFailed(reason: $reason)';
}


}




/// @nodoc
@JsonSerializable()

class SessionAutoContinuationUnknown implements SessionAutoContinuationStatus {
  const SessionAutoContinuationUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory SessionAutoContinuationUnknown.fromJson(Map<String, dynamic> json) => _$SessionAutoContinuationUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAutoContinuationUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAutoContinuationUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAutoContinuationStatus.unknown()';
}


}




// dart format on
