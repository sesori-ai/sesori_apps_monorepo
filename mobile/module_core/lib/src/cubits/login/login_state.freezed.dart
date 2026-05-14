// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LoginState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState()';
}


}

/// @nodoc
class $LoginStateCopyWith<$Res>  {
$LoginStateCopyWith(LoginState _, $Res Function(LoginState) __);
}



/// @nodoc


class LoginIdle implements LoginState {
  const LoginIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.idle()';
}


}




/// @nodoc


class LoginAuthenticating implements LoginState {
  const LoginAuthenticating();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginAuthenticating);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.authenticating()';
}


}




/// @nodoc


class LoginAwaitingConfirmation implements LoginState {
  const LoginAwaitingConfirmation({required this.userCode});
  

 final  String userCode;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginAwaitingConfirmationCopyWith<LoginAwaitingConfirmation> get copyWith => _$LoginAwaitingConfirmationCopyWithImpl<LoginAwaitingConfirmation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginAwaitingConfirmation&&(identical(other.userCode, userCode) || other.userCode == userCode));
}


@override
int get hashCode => Object.hash(runtimeType,userCode);

@override
String toString() {
  return 'LoginState.awaitingConfirmation(userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $LoginAwaitingConfirmationCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory $LoginAwaitingConfirmationCopyWith(LoginAwaitingConfirmation value, $Res Function(LoginAwaitingConfirmation) _then) = _$LoginAwaitingConfirmationCopyWithImpl;
@useResult
$Res call({
 String userCode
});




}
/// @nodoc
class _$LoginAwaitingConfirmationCopyWithImpl<$Res>
    implements $LoginAwaitingConfirmationCopyWith<$Res> {
  _$LoginAwaitingConfirmationCopyWithImpl(this._self, this._then);

  final LoginAwaitingConfirmation _self;
  final $Res Function(LoginAwaitingConfirmation) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userCode = null,}) {
  return _then(LoginAwaitingConfirmation(
userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginPolling implements LoginState {
  const LoginPolling();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginPolling);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.polling()';
}


}




/// @nodoc


class LoginTimeout implements LoginState {
  const LoginTimeout();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginTimeout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.timeout()';
}


}




/// @nodoc


class LoginSuccess implements LoginState {
  const LoginSuccess();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginSuccess);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LoginState.success()';
}


}




/// @nodoc


class LoginFailed implements LoginState {
  const LoginFailed({required this.reason});
  

 final  LoginFailedReason reason;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginFailedCopyWith<LoginFailed> get copyWith => _$LoginFailedCopyWithImpl<LoginFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginFailed&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'LoginState.failed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $LoginFailedCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory $LoginFailedCopyWith(LoginFailed value, $Res Function(LoginFailed) _then) = _$LoginFailedCopyWithImpl;
@useResult
$Res call({
 LoginFailedReason reason
});




}
/// @nodoc
class _$LoginFailedCopyWithImpl<$Res>
    implements $LoginFailedCopyWith<$Res> {
  _$LoginFailedCopyWithImpl(this._self, this._then);

  final LoginFailed _self;
  final $Res Function(LoginFailed) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(LoginFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as LoginFailedReason,
  ));
}


}

// dart format on
