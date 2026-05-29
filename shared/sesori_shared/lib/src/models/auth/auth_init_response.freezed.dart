// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_init_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthInitResponse {

 String get authUrl; String get state; String get userCode; int get expiresIn;
/// Create a copy of AuthInitResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthInitResponseCopyWith<AuthInitResponse> get copyWith => _$AuthInitResponseCopyWithImpl<AuthInitResponse>(this as AuthInitResponse, _$identity);

  /// Serializes this AuthInitResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthInitResponse&&(identical(other.authUrl, authUrl) || other.authUrl == authUrl)&&(identical(other.state, state) || other.state == state)&&(identical(other.userCode, userCode) || other.userCode == userCode)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authUrl,state,userCode,expiresIn);

@override
String toString() {
  return 'AuthInitResponse(authUrl: $authUrl, state: $state, userCode: $userCode, expiresIn: $expiresIn)';
}


}

/// @nodoc
abstract mixin class $AuthInitResponseCopyWith<$Res>  {
  factory $AuthInitResponseCopyWith(AuthInitResponse value, $Res Function(AuthInitResponse) _then) = _$AuthInitResponseCopyWithImpl;
@useResult
$Res call({
 String authUrl, String state, String userCode, int expiresIn
});




}
/// @nodoc
class _$AuthInitResponseCopyWithImpl<$Res>
    implements $AuthInitResponseCopyWith<$Res> {
  _$AuthInitResponseCopyWithImpl(this._self, this._then);

  final AuthInitResponse _self;
  final $Res Function(AuthInitResponse) _then;

/// Create a copy of AuthInitResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? authUrl = null,Object? state = null,Object? userCode = null,Object? expiresIn = null,}) {
  return _then(_self.copyWith(
authUrl: null == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AuthInitResponse implements AuthInitResponse {
  const _AuthInitResponse({required this.authUrl, required this.state, required this.userCode, required this.expiresIn});
  factory _AuthInitResponse.fromJson(Map<String, dynamic> json) => _$AuthInitResponseFromJson(json);

@override final  String authUrl;
@override final  String state;
@override final  String userCode;
@override final  int expiresIn;

/// Create a copy of AuthInitResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthInitResponseCopyWith<_AuthInitResponse> get copyWith => __$AuthInitResponseCopyWithImpl<_AuthInitResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthInitResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthInitResponse&&(identical(other.authUrl, authUrl) || other.authUrl == authUrl)&&(identical(other.state, state) || other.state == state)&&(identical(other.userCode, userCode) || other.userCode == userCode)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authUrl,state,userCode,expiresIn);

@override
String toString() {
  return 'AuthInitResponse(authUrl: $authUrl, state: $state, userCode: $userCode, expiresIn: $expiresIn)';
}


}

/// @nodoc
abstract mixin class _$AuthInitResponseCopyWith<$Res> implements $AuthInitResponseCopyWith<$Res> {
  factory _$AuthInitResponseCopyWith(_AuthInitResponse value, $Res Function(_AuthInitResponse) _then) = __$AuthInitResponseCopyWithImpl;
@override @useResult
$Res call({
 String authUrl, String state, String userCode, int expiresIn
});




}
/// @nodoc
class __$AuthInitResponseCopyWithImpl<$Res>
    implements _$AuthInitResponseCopyWith<$Res> {
  __$AuthInitResponseCopyWithImpl(this._self, this._then);

  final _AuthInitResponse _self;
  final $Res Function(_AuthInitResponse) _then;

/// Create a copy of AuthInitResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? authUrl = null,Object? state = null,Object? userCode = null,Object? expiresIn = null,}) {
  return _then(_AuthInitResponse(
authUrl: null == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
