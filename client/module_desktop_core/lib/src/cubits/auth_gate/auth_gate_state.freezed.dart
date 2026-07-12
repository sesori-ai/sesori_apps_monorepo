// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_gate_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthGateState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthGateState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthGateState()';
}


}

/// @nodoc
class $AuthGateStateCopyWith<$Res>  {
$AuthGateStateCopyWith(AuthGateState _, $Res Function(AuthGateState) __);
}



/// @nodoc


class AuthGateChecking implements AuthGateState {
  const AuthGateChecking();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthGateChecking);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthGateState.checking()';
}


}




/// @nodoc


class AuthGateSignedOut implements AuthGateState {
  const AuthGateSignedOut();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthGateSignedOut);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthGateState.signedOut()';
}


}




/// @nodoc


class AuthGateSignedIn implements AuthGateState {
  const AuthGateSignedIn({required this.user});
  

 final  AuthUser? user;

/// Create a copy of AuthGateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthGateSignedInCopyWith<AuthGateSignedIn> get copyWith => _$AuthGateSignedInCopyWithImpl<AuthGateSignedIn>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthGateSignedIn&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'AuthGateState.signedIn(user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthGateSignedInCopyWith<$Res> implements $AuthGateStateCopyWith<$Res> {
  factory $AuthGateSignedInCopyWith(AuthGateSignedIn value, $Res Function(AuthGateSignedIn) _then) = _$AuthGateSignedInCopyWithImpl;
@useResult
$Res call({
 AuthUser? user
});


$AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class _$AuthGateSignedInCopyWithImpl<$Res>
    implements $AuthGateSignedInCopyWith<$Res> {
  _$AuthGateSignedInCopyWithImpl(this._self, this._then);

  final AuthGateSignedIn _self;
  final $Res Function(AuthGateSignedIn) _then;

/// Create a copy of AuthGateState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = freezed,}) {
  return _then(AuthGateSignedIn(
user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,
  ));
}

/// Create a copy of AuthGateState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $AuthUserCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
