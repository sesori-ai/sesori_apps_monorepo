// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_me_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthMeResponse {

 AuthUser get user;
/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthMeResponseCopyWith<AuthMeResponse> get copyWith => _$AuthMeResponseCopyWithImpl<AuthMeResponse>(this as AuthMeResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthMeResponse&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'AuthMeResponse(user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthMeResponseCopyWith<$Res>  {
  factory $AuthMeResponseCopyWith(AuthMeResponse value, $Res Function(AuthMeResponse) _then) = _$AuthMeResponseCopyWithImpl;
@useResult
$Res call({
 AuthUser user
});


$AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class _$AuthMeResponseCopyWithImpl<$Res>
    implements $AuthMeResponseCopyWith<$Res> {
  _$AuthMeResponseCopyWithImpl(this._self, this._then);

  final AuthMeResponse _self;
  final $Res Function(AuthMeResponse) _then;

/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,
  ));
}
/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res> get user {
  
  return $AuthUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _AuthMeResponse implements AuthMeResponse {
  const _AuthMeResponse({required this.user});
  factory _AuthMeResponse.fromJson(Map<String, dynamic> json) => _$AuthMeResponseFromJson(json);

@override final  AuthUser user;

/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthMeResponseCopyWith<_AuthMeResponse> get copyWith => __$AuthMeResponseCopyWithImpl<_AuthMeResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthMeResponse&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'AuthMeResponse(user: $user)';
}


}

/// @nodoc
abstract mixin class _$AuthMeResponseCopyWith<$Res> implements $AuthMeResponseCopyWith<$Res> {
  factory _$AuthMeResponseCopyWith(_AuthMeResponse value, $Res Function(_AuthMeResponse) _then) = __$AuthMeResponseCopyWithImpl;
@override @useResult
$Res call({
 AuthUser user
});


@override $AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class __$AuthMeResponseCopyWithImpl<$Res>
    implements _$AuthMeResponseCopyWith<$Res> {
  __$AuthMeResponseCopyWithImpl(this._self, this._then);

  final _AuthMeResponse _self;
  final $Res Function(_AuthMeResponse) _then;

/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,}) {
  return _then(_AuthMeResponse(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,
  ));
}

/// Create a copy of AuthMeResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res> get user {
  
  return $AuthUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
