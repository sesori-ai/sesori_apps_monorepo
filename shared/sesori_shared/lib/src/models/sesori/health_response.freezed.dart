// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthResponse {

 bool get healthy; String get version; bool get filesystemAccessDegraded;@JsonKey(unknownEnumValue: BridgeKind.cli) BridgeKind get bridgeKind;
/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthResponseCopyWith<HealthResponse> get copyWith => _$HealthResponseCopyWithImpl<HealthResponse>(this as HealthResponse, _$identity);

  /// Serializes this HealthResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HealthResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthResponse&&(identical(other.healthy, _this.healthy) || other.healthy == _this.healthy)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.filesystemAccessDegraded, _this.filesystemAccessDegraded) || other.filesystemAccessDegraded == _this.filesystemAccessDegraded)&&(identical(other.bridgeKind, _this.bridgeKind) || other.bridgeKind == _this.bridgeKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HealthResponse;
  return Object.hash(runtimeType,_this.healthy,_this.version,_this.filesystemAccessDegraded,_this.bridgeKind);
}

@override
String toString() {
  final _this = this as HealthResponse;
  return 'HealthResponse(healthy: ${_this.healthy}, version: ${_this.version}, filesystemAccessDegraded: ${_this.filesystemAccessDegraded}, bridgeKind: ${_this.bridgeKind})';
}


}

/// @nodoc
abstract mixin class $HealthResponseCopyWith<$Res>  {
  factory $HealthResponseCopyWith(HealthResponse value, $Res Function(HealthResponse) _then) = _$HealthResponseCopyWithImpl;
@useResult
$Res call({
 bool healthy, String version, bool filesystemAccessDegraded,@JsonKey(unknownEnumValue: BridgeKind.cli) BridgeKind bridgeKind
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
@pragma('vm:prefer-inline') @override $Res call({Object? healthy = null,Object? version = null,Object? filesystemAccessDegraded = null,Object? bridgeKind = null,}) {
  return _then(HealthResponse(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,filesystemAccessDegraded: null == filesystemAccessDegraded ? _self.filesystemAccessDegraded : filesystemAccessDegraded // ignore: cast_nullable_to_non_nullable
as bool,bridgeKind: null == bridgeKind ? _self.bridgeKind : bridgeKind // ignore: cast_nullable_to_non_nullable
as BridgeKind,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HealthResponse implements HealthResponse {
  const _HealthResponse({required this.healthy, required this.version, required this.filesystemAccessDegraded, @JsonKey(unknownEnumValue: BridgeKind.cli) this.bridgeKind = BridgeKind.cli});
  factory _HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);

@override final  bool healthy;
@override final  String version;
@override final  bool filesystemAccessDegraded;
@override@JsonKey(unknownEnumValue: BridgeKind.cli) final  BridgeKind bridgeKind;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthResponse&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.version, version) || other.version == version)&&(identical(other.filesystemAccessDegraded, filesystemAccessDegraded) || other.filesystemAccessDegraded == filesystemAccessDegraded)&&(identical(other.bridgeKind, bridgeKind) || other.bridgeKind == bridgeKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,healthy,version,filesystemAccessDegraded,bridgeKind);
}

@override
String toString() {
    return 'HealthResponse(healthy: $healthy, version: $version, filesystemAccessDegraded: $filesystemAccessDegraded, bridgeKind: $bridgeKind)';
}


}

/// @nodoc
abstract mixin class _$HealthResponseCopyWith<$Res> implements $HealthResponseCopyWith<$Res> {
  factory _$HealthResponseCopyWith(_HealthResponse value, $Res Function(_HealthResponse) _then) = __$HealthResponseCopyWithImpl;
@override @useResult
$Res call({
 bool healthy, String version, bool filesystemAccessDegraded,@JsonKey(unknownEnumValue: BridgeKind.cli) BridgeKind bridgeKind
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
@override @pragma('vm:prefer-inline') $Res call({Object? healthy = null,Object? version = null,Object? filesystemAccessDegraded = null,Object? bridgeKind = null,}) {
  return _then(_HealthResponse(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,filesystemAccessDegraded: null == filesystemAccessDegraded ? _self.filesystemAccessDegraded : filesystemAccessDegraded // ignore: cast_nullable_to_non_nullable
as bool,bridgeKind: null == bridgeKind ? _self.bridgeKind : bridgeKind // ignore: cast_nullable_to_non_nullable
as BridgeKind,
  ));
}


}

// dart format on
