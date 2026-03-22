// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'register_token_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterTokenRequest {

 String get token; DevicePlatform get platform;
/// Create a copy of RegisterTokenRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterTokenRequestCopyWith<RegisterTokenRequest> get copyWith => _$RegisterTokenRequestCopyWithImpl<RegisterTokenRequest>(this as RegisterTokenRequest, _$identity);

  /// Serializes this RegisterTokenRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterTokenRequest&&(identical(other.token, token) || other.token == token)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,platform);

@override
String toString() {
  return 'RegisterTokenRequest(token: $token, platform: $platform)';
}


}

/// @nodoc
abstract mixin class $RegisterTokenRequestCopyWith<$Res>  {
  factory $RegisterTokenRequestCopyWith(RegisterTokenRequest value, $Res Function(RegisterTokenRequest) _then) = _$RegisterTokenRequestCopyWithImpl;
@useResult
$Res call({
 String token, DevicePlatform platform
});




}
/// @nodoc
class _$RegisterTokenRequestCopyWithImpl<$Res>
    implements $RegisterTokenRequestCopyWith<$Res> {
  _$RegisterTokenRequestCopyWithImpl(this._self, this._then);

  final RegisterTokenRequest _self;
  final $Res Function(RegisterTokenRequest) _then;

/// Create a copy of RegisterTokenRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? platform = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _RegisterTokenRequest implements RegisterTokenRequest {
  const _RegisterTokenRequest({required this.token, required this.platform});
  factory _RegisterTokenRequest.fromJson(Map<String, dynamic> json) => _$RegisterTokenRequestFromJson(json);

@override final  String token;
@override final  DevicePlatform platform;

/// Create a copy of RegisterTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterTokenRequestCopyWith<_RegisterTokenRequest> get copyWith => __$RegisterTokenRequestCopyWithImpl<_RegisterTokenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterTokenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterTokenRequest&&(identical(other.token, token) || other.token == token)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,platform);

@override
String toString() {
  return 'RegisterTokenRequest(token: $token, platform: $platform)';
}


}

/// @nodoc
abstract mixin class _$RegisterTokenRequestCopyWith<$Res> implements $RegisterTokenRequestCopyWith<$Res> {
  factory _$RegisterTokenRequestCopyWith(_RegisterTokenRequest value, $Res Function(_RegisterTokenRequest) _then) = __$RegisterTokenRequestCopyWithImpl;
@override @useResult
$Res call({
 String token, DevicePlatform platform
});




}
/// @nodoc
class __$RegisterTokenRequestCopyWithImpl<$Res>
    implements _$RegisterTokenRequestCopyWith<$Res> {
  __$RegisterTokenRequestCopyWithImpl(this._self, this._then);

  final _RegisterTokenRequest _self;
  final $Res Function(_RegisterTokenRequest) _then;

/// Create a copy of RegisterTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? platform = null,}) {
  return _then(_RegisterTokenRequest(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,
  ));
}


}

// dart format on
