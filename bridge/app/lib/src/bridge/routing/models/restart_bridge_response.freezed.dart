// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'restart_bridge_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RestartBridgeResponse {

 bool get restarting;
/// Create a copy of RestartBridgeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestartBridgeResponseCopyWith<RestartBridgeResponse> get copyWith => _$RestartBridgeResponseCopyWithImpl<RestartBridgeResponse>(this as RestartBridgeResponse, _$identity);

  /// Serializes this RestartBridgeResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestartBridgeResponse&&(identical(other.restarting, restarting) || other.restarting == restarting));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restarting);

@override
String toString() {
  return 'RestartBridgeResponse(restarting: $restarting)';
}


}

/// @nodoc
abstract mixin class $RestartBridgeResponseCopyWith<$Res>  {
  factory $RestartBridgeResponseCopyWith(RestartBridgeResponse value, $Res Function(RestartBridgeResponse) _then) = _$RestartBridgeResponseCopyWithImpl;
@useResult
$Res call({
 bool restarting
});




}
/// @nodoc
class _$RestartBridgeResponseCopyWithImpl<$Res>
    implements $RestartBridgeResponseCopyWith<$Res> {
  _$RestartBridgeResponseCopyWithImpl(this._self, this._then);

  final RestartBridgeResponse _self;
  final $Res Function(RestartBridgeResponse) _then;

/// Create a copy of RestartBridgeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? restarting = null,}) {
  return _then(_self.copyWith(
restarting: null == restarting ? _self.restarting : restarting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _RestartBridgeResponse implements RestartBridgeResponse {
  const _RestartBridgeResponse({required this.restarting});
  

@override final  bool restarting;

/// Create a copy of RestartBridgeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestartBridgeResponseCopyWith<_RestartBridgeResponse> get copyWith => __$RestartBridgeResponseCopyWithImpl<_RestartBridgeResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestartBridgeResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestartBridgeResponse&&(identical(other.restarting, restarting) || other.restarting == restarting));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restarting);

@override
String toString() {
  return 'RestartBridgeResponse(restarting: $restarting)';
}


}

/// @nodoc
abstract mixin class _$RestartBridgeResponseCopyWith<$Res> implements $RestartBridgeResponseCopyWith<$Res> {
  factory _$RestartBridgeResponseCopyWith(_RestartBridgeResponse value, $Res Function(_RestartBridgeResponse) _then) = __$RestartBridgeResponseCopyWithImpl;
@override @useResult
$Res call({
 bool restarting
});




}
/// @nodoc
class __$RestartBridgeResponseCopyWithImpl<$Res>
    implements _$RestartBridgeResponseCopyWith<$Res> {
  __$RestartBridgeResponseCopyWithImpl(this._self, this._then);

  final _RestartBridgeResponse _self;
  final $Res Function(_RestartBridgeResponse) _then;

/// Create a copy of RestartBridgeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? restarting = null,}) {
  return _then(_RestartBridgeResponse(
restarting: null == restarting ? _self.restarting : restarting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
