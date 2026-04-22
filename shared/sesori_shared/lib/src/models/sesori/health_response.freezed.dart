// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthResponse {

 bool get healthy; String get version; bool? get serverManaged; ServerStateKind? get serverState;
/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthResponseCopyWith<HealthResponse> get copyWith => _$HealthResponseCopyWithImpl<HealthResponse>(this as HealthResponse, _$identity);

  /// Serializes this HealthResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthResponse&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.version, version) || other.version == version)&&(identical(other.serverManaged, serverManaged) || other.serverManaged == serverManaged)&&(identical(other.serverState, serverState) || other.serverState == serverState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthy,version,serverManaged,serverState);

@override
String toString() {
  return 'HealthResponse(healthy: $healthy, version: $version, serverManaged: $serverManaged, serverState: $serverState)';
}


}

/// @nodoc
abstract mixin class $HealthResponseCopyWith<$Res>  {
  factory $HealthResponseCopyWith(HealthResponse value, $Res Function(HealthResponse) _then) = _$HealthResponseCopyWithImpl;
@useResult
$Res call({
 bool healthy, String version, bool? serverManaged, ServerStateKind? serverState
});




}
/// @nodoc
class _$HealthResponseCopyWithImpl<$Res>
    implements $HealthResponseCopyWith<$Res> {
  _$HealthResponseCopyWithImpl(this._self, this._then);

  final HealthResponse _self;
  final $Res Function(HealthResponse) _then;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? healthy = null,Object? version = null,Object? serverManaged = freezed,Object? serverState = freezed,}) {
  return _then(_self.copyWith(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,serverManaged: freezed == serverManaged ? _self.serverManaged : serverManaged // ignore: cast_nullable_to_non_nullable
as bool?,serverState: freezed == serverState ? _self.serverState : serverState // ignore: cast_nullable_to_non_nullable
as ServerStateKind?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HealthResponse implements HealthResponse {
  const _HealthResponse({required this.healthy, required this.version, required this.serverManaged, required this.serverState});
  factory _HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);

@override final  bool healthy;
@override final  String version;
@override final  bool? serverManaged;
@override final  ServerStateKind? serverState;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthResponseCopyWith<_HealthResponse> get copyWith => __$HealthResponseCopyWithImpl<_HealthResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthResponse&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.version, version) || other.version == version)&&(identical(other.serverManaged, serverManaged) || other.serverManaged == serverManaged)&&(identical(other.serverState, serverState) || other.serverState == serverState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthy,version,serverManaged,serverState);

@override
String toString() {
  return 'HealthResponse(healthy: $healthy, version: $version, serverManaged: $serverManaged, serverState: $serverState)';
}


}

/// @nodoc
abstract mixin class _$HealthResponseCopyWith<$Res> implements $HealthResponseCopyWith<$Res> {
  factory _$HealthResponseCopyWith(_HealthResponse value, $Res Function(_HealthResponse) _then) = __$HealthResponseCopyWithImpl;
@override @useResult
$Res call({
 bool healthy, String version, bool? serverManaged, ServerStateKind? serverState
});




}
/// @nodoc
class __$HealthResponseCopyWithImpl<$Res>
    implements _$HealthResponseCopyWith<$Res> {
  __$HealthResponseCopyWithImpl(this._self, this._then);

  final _HealthResponse _self;
  final $Res Function(_HealthResponse) _then;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? healthy = null,Object? version = null,Object? serverManaged = freezed,Object? serverState = freezed,}) {
  return _then(_HealthResponse(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,serverManaged: freezed == serverManaged ? _self.serverManaged : serverManaged // ignore: cast_nullable_to_non_nullable
as bool?,serverState: freezed == serverState ? _self.serverState : serverState // ignore: cast_nullable_to_non_nullable
as ServerStateKind?,
  ));
}


}

// dart format on
