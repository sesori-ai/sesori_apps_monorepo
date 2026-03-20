// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_connection_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServerConnectionConfig {

 String get relayHost; String? get authToken;
/// Create a copy of ServerConnectionConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerConnectionConfigCopyWith<ServerConnectionConfig> get copyWith => _$ServerConnectionConfigCopyWithImpl<ServerConnectionConfig>(this as ServerConnectionConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerConnectionConfig&&(identical(other.relayHost, relayHost) || other.relayHost == relayHost)&&(identical(other.authToken, authToken) || other.authToken == authToken));
}


@override
int get hashCode => Object.hash(runtimeType,relayHost,authToken);

@override
String toString() {
  return 'ServerConnectionConfig(relayHost: $relayHost, authToken: $authToken)';
}


}

/// @nodoc
abstract mixin class $ServerConnectionConfigCopyWith<$Res>  {
  factory $ServerConnectionConfigCopyWith(ServerConnectionConfig value, $Res Function(ServerConnectionConfig) _then) = _$ServerConnectionConfigCopyWithImpl;
@useResult
$Res call({
 String relayHost, String? authToken
});




}
/// @nodoc
class _$ServerConnectionConfigCopyWithImpl<$Res>
    implements $ServerConnectionConfigCopyWith<$Res> {
  _$ServerConnectionConfigCopyWithImpl(this._self, this._then);

  final ServerConnectionConfig _self;
  final $Res Function(ServerConnectionConfig) _then;

/// Create a copy of ServerConnectionConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? relayHost = null,Object? authToken = freezed,}) {
  return _then(_self.copyWith(
relayHost: null == relayHost ? _self.relayHost : relayHost // ignore: cast_nullable_to_non_nullable
as String,authToken: freezed == authToken ? _self.authToken : authToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc


class _ServerConnectionConfig implements ServerConnectionConfig {
  const _ServerConnectionConfig({required this.relayHost, this.authToken});
  

@override final  String relayHost;
@override final  String? authToken;

/// Create a copy of ServerConnectionConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerConnectionConfigCopyWith<_ServerConnectionConfig> get copyWith => __$ServerConnectionConfigCopyWithImpl<_ServerConnectionConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerConnectionConfig&&(identical(other.relayHost, relayHost) || other.relayHost == relayHost)&&(identical(other.authToken, authToken) || other.authToken == authToken));
}


@override
int get hashCode => Object.hash(runtimeType,relayHost,authToken);

@override
String toString() {
  return 'ServerConnectionConfig(relayHost: $relayHost, authToken: $authToken)';
}


}

/// @nodoc
abstract mixin class _$ServerConnectionConfigCopyWith<$Res> implements $ServerConnectionConfigCopyWith<$Res> {
  factory _$ServerConnectionConfigCopyWith(_ServerConnectionConfig value, $Res Function(_ServerConnectionConfig) _then) = __$ServerConnectionConfigCopyWithImpl;
@override @useResult
$Res call({
 String relayHost, String? authToken
});




}
/// @nodoc
class __$ServerConnectionConfigCopyWithImpl<$Res>
    implements _$ServerConnectionConfigCopyWith<$Res> {
  __$ServerConnectionConfigCopyWithImpl(this._self, this._then);

  final _ServerConnectionConfig _self;
  final $Res Function(_ServerConnectionConfig) _then;

/// Create a copy of ServerConnectionConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? relayHost = null,Object? authToken = freezed,}) {
  return _then(_ServerConnectionConfig(
relayHost: null == relayHost ? _self.relayHost : relayHost // ignore: cast_nullable_to_non_nullable
as String,authToken: freezed == authToken ? _self.authToken : authToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
