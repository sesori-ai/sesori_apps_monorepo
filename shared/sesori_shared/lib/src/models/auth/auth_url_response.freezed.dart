// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_url_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthUrlResponse {

 String get authUrl; String get state;
/// Create a copy of AuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthUrlResponseCopyWith<AuthUrlResponse> get copyWith => _$AuthUrlResponseCopyWithImpl<AuthUrlResponse>(this as AuthUrlResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUrlResponse&&(identical(other.authUrl, authUrl) || other.authUrl == authUrl)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authUrl,state);

@override
String toString() {
  return 'AuthUrlResponse(authUrl: $authUrl, state: $state)';
}


}

/// @nodoc
abstract mixin class $AuthUrlResponseCopyWith<$Res>  {
  factory $AuthUrlResponseCopyWith(AuthUrlResponse value, $Res Function(AuthUrlResponse) _then) = _$AuthUrlResponseCopyWithImpl;
@useResult
$Res call({
 String authUrl, String state
});




}
/// @nodoc
class _$AuthUrlResponseCopyWithImpl<$Res>
    implements $AuthUrlResponseCopyWith<$Res> {
  _$AuthUrlResponseCopyWithImpl(this._self, this._then);

  final AuthUrlResponse _self;
  final $Res Function(AuthUrlResponse) _then;

/// Create a copy of AuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? authUrl = null,Object? state = null,}) {
  return _then(_self.copyWith(
authUrl: null == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _AuthUrlResponse implements AuthUrlResponse {
  const _AuthUrlResponse({required this.authUrl, required this.state});
  factory _AuthUrlResponse.fromJson(Map<String, dynamic> json) => _$AuthUrlResponseFromJson(json);

@override final  String authUrl;
@override final  String state;

/// Create a copy of AuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthUrlResponseCopyWith<_AuthUrlResponse> get copyWith => __$AuthUrlResponseCopyWithImpl<_AuthUrlResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthUrlResponse&&(identical(other.authUrl, authUrl) || other.authUrl == authUrl)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authUrl,state);

@override
String toString() {
  return 'AuthUrlResponse(authUrl: $authUrl, state: $state)';
}


}

/// @nodoc
abstract mixin class _$AuthUrlResponseCopyWith<$Res> implements $AuthUrlResponseCopyWith<$Res> {
  factory _$AuthUrlResponseCopyWith(_AuthUrlResponse value, $Res Function(_AuthUrlResponse) _then) = __$AuthUrlResponseCopyWithImpl;
@override @useResult
$Res call({
 String authUrl, String state
});




}
/// @nodoc
class __$AuthUrlResponseCopyWithImpl<$Res>
    implements _$AuthUrlResponseCopyWith<$Res> {
  __$AuthUrlResponseCopyWithImpl(this._self, this._then);

  final _AuthUrlResponse _self;
  final $Res Function(_AuthUrlResponse) _then;

/// Create a copy of AuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? authUrl = null,Object? state = null,}) {
  return _then(_AuthUrlResponse(
authUrl: null == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
