// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'register_fid_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterFidRequest {

 String get fid; DevicePlatform get platform; String get deviceId;
/// Create a copy of RegisterFidRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterFidRequestCopyWith<RegisterFidRequest> get copyWith => _$RegisterFidRequestCopyWithImpl<RegisterFidRequest>(this as RegisterFidRequest, _$identity);

  /// Serializes this RegisterFidRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RegisterFidRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterFidRequest&&(identical(other.fid, _this.fid) || other.fid == _this.fid)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RegisterFidRequest;
  return Object.hash(runtimeType,_this.fid,_this.platform,_this.deviceId);
}

@override
String toString() {
  final _this = this as RegisterFidRequest;
  return 'RegisterFidRequest(fid: ${_this.fid}, platform: ${_this.platform}, deviceId: ${_this.deviceId})';
}


}

/// @nodoc
abstract mixin class $RegisterFidRequestCopyWith<$Res>  {
  factory $RegisterFidRequestCopyWith(RegisterFidRequest value, $Res Function(RegisterFidRequest) _then) = _$RegisterFidRequestCopyWithImpl;
@useResult
$Res call({
 String fid, DevicePlatform platform, String deviceId
});




}
/// @nodoc
class _$RegisterFidRequestCopyWithImpl<$Res>
    implements $RegisterFidRequestCopyWith<$Res> {
  _$RegisterFidRequestCopyWithImpl(this._self, this._then);

  final RegisterFidRequest _self;
  final $Res Function(RegisterFidRequest) _then;

/// Create a copy of RegisterFidRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fid = null,Object? platform = null,Object? deviceId = null,}) {
  return _then(RegisterFidRequest(
fid: null == fid ? _self.fid : fid // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _RegisterFidRequest implements RegisterFidRequest {
  const _RegisterFidRequest({required this.fid, required this.platform, required this.deviceId});
  factory _RegisterFidRequest.fromJson(Map<String, dynamic> json) => _$RegisterFidRequestFromJson(json);

@override final  String fid;
@override final  DevicePlatform platform;
@override final  String deviceId;

/// Create a copy of RegisterFidRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterFidRequestCopyWith<_RegisterFidRequest> get copyWith => __$RegisterFidRequestCopyWithImpl<_RegisterFidRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterFidRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterFidRequest&&(identical(other.fid, fid) || other.fid == fid)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fid,platform,deviceId);
}

@override
String toString() {
    return 'RegisterFidRequest(fid: $fid, platform: $platform, deviceId: $deviceId)';
}


}

/// @nodoc
abstract mixin class _$RegisterFidRequestCopyWith<$Res> implements $RegisterFidRequestCopyWith<$Res> {
  factory _$RegisterFidRequestCopyWith(_RegisterFidRequest value, $Res Function(_RegisterFidRequest) _then) = __$RegisterFidRequestCopyWithImpl;
@override @useResult
$Res call({
 String fid, DevicePlatform platform, String deviceId
});




}
/// @nodoc
class __$RegisterFidRequestCopyWithImpl<$Res>
    implements _$RegisterFidRequestCopyWith<$Res> {
  __$RegisterFidRequestCopyWithImpl(this._self, this._then);

  final _RegisterFidRequest _self;
  final $Res Function(_RegisterFidRequest) _then;

/// Create a copy of RegisterFidRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fid = null,Object? platform = null,Object? deviceId = null,}) {
  return _then(_RegisterFidRequest(
fid: null == fid ? _self.fid : fid // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
