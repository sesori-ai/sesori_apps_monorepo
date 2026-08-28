// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_input_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VoiceInputState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState()';
}


}

/// @nodoc
class $VoiceInputStateCopyWith<$Res>  {
$VoiceInputStateCopyWith(VoiceInputState _, $Res Function(VoiceInputState) __);
}



/// @nodoc


class VoiceInputIdle implements VoiceInputState {
  const VoiceInputIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState.idle()';
}


}




/// @nodoc


class VoiceInputStarting implements VoiceInputState {
  const VoiceInputStarting();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputStarting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState.starting()';
}


}




/// @nodoc


class VoiceInputRecording implements VoiceInputState {
  const VoiceInputRecording();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputRecording);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState.recording()';
}


}




/// @nodoc


class VoiceInputTranscribing implements VoiceInputState {
  const VoiceInputTranscribing({required this.limitReached});
  

 final  bool limitReached;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputTranscribingCopyWith<VoiceInputTranscribing> get copyWith => _$VoiceInputTranscribingCopyWithImpl<VoiceInputTranscribing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputTranscribing&&(identical(other.limitReached, limitReached) || other.limitReached == limitReached));
}


@override
int get hashCode => Object.hash(runtimeType,limitReached);

@override
String toString() {
  return 'VoiceInputState.transcribing(limitReached: $limitReached)';
}


}

/// @nodoc
abstract mixin class $VoiceInputTranscribingCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputTranscribingCopyWith(VoiceInputTranscribing value, $Res Function(VoiceInputTranscribing) _then) = _$VoiceInputTranscribingCopyWithImpl;
@useResult
$Res call({
 bool limitReached
});




}
/// @nodoc
class _$VoiceInputTranscribingCopyWithImpl<$Res>
    implements $VoiceInputTranscribingCopyWith<$Res> {
  _$VoiceInputTranscribingCopyWithImpl(this._self, this._then);

  final VoiceInputTranscribing _self;
  final $Res Function(VoiceInputTranscribing) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? limitReached = null,}) {
  return _then(VoiceInputTranscribing(
limitReached: null == limitReached ? _self.limitReached : limitReached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VoiceInputRetryPending implements VoiceInputState {
  const VoiceInputRetryPending({required this.error});
  

 final  VoiceTranscriptionError error;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputRetryPendingCopyWith<VoiceInputRetryPending> get copyWith => _$VoiceInputRetryPendingCopyWithImpl<VoiceInputRetryPending>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputRetryPending&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'VoiceInputState.retryPending(error: $error)';
}


}

/// @nodoc
abstract mixin class $VoiceInputRetryPendingCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputRetryPendingCopyWith(VoiceInputRetryPending value, $Res Function(VoiceInputRetryPending) _then) = _$VoiceInputRetryPendingCopyWithImpl;
@useResult
$Res call({
 VoiceTranscriptionError error
});




}
/// @nodoc
class _$VoiceInputRetryPendingCopyWithImpl<$Res>
    implements $VoiceInputRetryPendingCopyWith<$Res> {
  _$VoiceInputRetryPendingCopyWithImpl(this._self, this._then);

  final VoiceInputRetryPending _self;
  final $Res Function(VoiceInputRetryPending) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(VoiceInputRetryPending(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VoiceTranscriptionError,
  ));
}


}

/// @nodoc


class VoiceInputRetrying implements VoiceInputState {
  const VoiceInputRetrying({required this.previousError});
  

 final  VoiceTranscriptionError previousError;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputRetryingCopyWith<VoiceInputRetrying> get copyWith => _$VoiceInputRetryingCopyWithImpl<VoiceInputRetrying>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputRetrying&&(identical(other.previousError, previousError) || other.previousError == previousError));
}


@override
int get hashCode => Object.hash(runtimeType,previousError);

@override
String toString() {
  return 'VoiceInputState.retrying(previousError: $previousError)';
}


}

/// @nodoc
abstract mixin class $VoiceInputRetryingCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputRetryingCopyWith(VoiceInputRetrying value, $Res Function(VoiceInputRetrying) _then) = _$VoiceInputRetryingCopyWithImpl;
@useResult
$Res call({
 VoiceTranscriptionError previousError
});




}
/// @nodoc
class _$VoiceInputRetryingCopyWithImpl<$Res>
    implements $VoiceInputRetryingCopyWith<$Res> {
  _$VoiceInputRetryingCopyWithImpl(this._self, this._then);

  final VoiceInputRetrying _self;
  final $Res Function(VoiceInputRetrying) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? previousError = null,}) {
  return _then(VoiceInputRetrying(
previousError: null == previousError ? _self.previousError : previousError // ignore: cast_nullable_to_non_nullable
as VoiceTranscriptionError,
  ));
}


}

/// @nodoc


class VoiceInputRetryCancelling implements VoiceInputState {
  const VoiceInputRetryCancelling({required this.previousError});
  

 final  VoiceTranscriptionError previousError;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputRetryCancellingCopyWith<VoiceInputRetryCancelling> get copyWith => _$VoiceInputRetryCancellingCopyWithImpl<VoiceInputRetryCancelling>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputRetryCancelling&&(identical(other.previousError, previousError) || other.previousError == previousError));
}


@override
int get hashCode => Object.hash(runtimeType,previousError);

@override
String toString() {
  return 'VoiceInputState.retryCancelling(previousError: $previousError)';
}


}

/// @nodoc
abstract mixin class $VoiceInputRetryCancellingCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputRetryCancellingCopyWith(VoiceInputRetryCancelling value, $Res Function(VoiceInputRetryCancelling) _then) = _$VoiceInputRetryCancellingCopyWithImpl;
@useResult
$Res call({
 VoiceTranscriptionError previousError
});




}
/// @nodoc
class _$VoiceInputRetryCancellingCopyWithImpl<$Res>
    implements $VoiceInputRetryCancellingCopyWith<$Res> {
  _$VoiceInputRetryCancellingCopyWithImpl(this._self, this._then);

  final VoiceInputRetryCancelling _self;
  final $Res Function(VoiceInputRetryCancelling) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? previousError = null,}) {
  return _then(VoiceInputRetryCancelling(
previousError: null == previousError ? _self.previousError : previousError // ignore: cast_nullable_to_non_nullable
as VoiceTranscriptionError,
  ));
}


}

/// @nodoc


class VoiceInputDiscarding implements VoiceInputState {
  const VoiceInputDiscarding();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputDiscarding);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState.discarding()';
}


}




/// @nodoc


class VoiceInputCompleted implements VoiceInputState {
  const VoiceInputCompleted({required this.transcript});
  

 final  String transcript;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputCompletedCopyWith<VoiceInputCompleted> get copyWith => _$VoiceInputCompletedCopyWithImpl<VoiceInputCompleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputCompleted&&(identical(other.transcript, transcript) || other.transcript == transcript));
}


@override
int get hashCode => Object.hash(runtimeType,transcript);

@override
String toString() {
  return 'VoiceInputState.completed(transcript: $transcript)';
}


}

/// @nodoc
abstract mixin class $VoiceInputCompletedCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputCompletedCopyWith(VoiceInputCompleted value, $Res Function(VoiceInputCompleted) _then) = _$VoiceInputCompletedCopyWithImpl;
@useResult
$Res call({
 String transcript
});




}
/// @nodoc
class _$VoiceInputCompletedCopyWithImpl<$Res>
    implements $VoiceInputCompletedCopyWith<$Res> {
  _$VoiceInputCompletedCopyWithImpl(this._self, this._then);

  final VoiceInputCompleted _self;
  final $Res Function(VoiceInputCompleted) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transcript = null,}) {
  return _then(VoiceInputCompleted(
transcript: null == transcript ? _self.transcript : transcript // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VoiceInputStartFailed implements VoiceInputState {
  const VoiceInputStartFailed({required this.error});
  

 final  VoiceTranscriptionError error;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputStartFailedCopyWith<VoiceInputStartFailed> get copyWith => _$VoiceInputStartFailedCopyWithImpl<VoiceInputStartFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputStartFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'VoiceInputState.startFailed(error: $error)';
}


}

/// @nodoc
abstract mixin class $VoiceInputStartFailedCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputStartFailedCopyWith(VoiceInputStartFailed value, $Res Function(VoiceInputStartFailed) _then) = _$VoiceInputStartFailedCopyWithImpl;
@useResult
$Res call({
 VoiceTranscriptionError error
});




}
/// @nodoc
class _$VoiceInputStartFailedCopyWithImpl<$Res>
    implements $VoiceInputStartFailedCopyWith<$Res> {
  _$VoiceInputStartFailedCopyWithImpl(this._self, this._then);

  final VoiceInputStartFailed _self;
  final $Res Function(VoiceInputStartFailed) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(VoiceInputStartFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VoiceTranscriptionError,
  ));
}


}

/// @nodoc


class VoiceInputTranscriptionFailed implements VoiceInputState {
  const VoiceInputTranscriptionFailed({required this.error});
  

 final  VoiceTranscriptionError error;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceInputTranscriptionFailedCopyWith<VoiceInputTranscriptionFailed> get copyWith => _$VoiceInputTranscriptionFailedCopyWithImpl<VoiceInputTranscriptionFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputTranscriptionFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'VoiceInputState.transcriptionFailed(error: $error)';
}


}

/// @nodoc
abstract mixin class $VoiceInputTranscriptionFailedCopyWith<$Res> implements $VoiceInputStateCopyWith<$Res> {
  factory $VoiceInputTranscriptionFailedCopyWith(VoiceInputTranscriptionFailed value, $Res Function(VoiceInputTranscriptionFailed) _then) = _$VoiceInputTranscriptionFailedCopyWithImpl;
@useResult
$Res call({
 VoiceTranscriptionError error
});




}
/// @nodoc
class _$VoiceInputTranscriptionFailedCopyWithImpl<$Res>
    implements $VoiceInputTranscriptionFailedCopyWith<$Res> {
  _$VoiceInputTranscriptionFailedCopyWithImpl(this._self, this._then);

  final VoiceInputTranscriptionFailed _self;
  final $Res Function(VoiceInputTranscriptionFailed) _then;

/// Create a copy of VoiceInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(VoiceInputTranscriptionFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VoiceTranscriptionError,
  ));
}


}

/// @nodoc


class VoiceInputCancelling implements VoiceInputState {
  const VoiceInputCancelling();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceInputCancelling);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VoiceInputState.cancelling()';
}


}




// dart format on
