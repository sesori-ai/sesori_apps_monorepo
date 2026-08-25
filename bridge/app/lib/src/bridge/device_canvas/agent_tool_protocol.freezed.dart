// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_tool_protocol.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceCanvasAgentToolRendezvous {

 int get protocolVersion; int get port;
/// Create a copy of DeviceCanvasAgentToolRendezvous
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolRendezvousCopyWith<DeviceCanvasAgentToolRendezvous> get copyWith => _$DeviceCanvasAgentToolRendezvousCopyWithImpl<DeviceCanvasAgentToolRendezvous>(this as DeviceCanvasAgentToolRendezvous, _$identity);

  /// Serializes this DeviceCanvasAgentToolRendezvous to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolRendezvous&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,port);

@override
String toString() {
  return 'DeviceCanvasAgentToolRendezvous(protocolVersion: $protocolVersion, port: $port)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolRendezvousCopyWith<$Res>  {
  factory $DeviceCanvasAgentToolRendezvousCopyWith(DeviceCanvasAgentToolRendezvous value, $Res Function(DeviceCanvasAgentToolRendezvous) _then) = _$DeviceCanvasAgentToolRendezvousCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, int port
});




}
/// @nodoc
class _$DeviceCanvasAgentToolRendezvousCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolRendezvousCopyWith<$Res> {
  _$DeviceCanvasAgentToolRendezvousCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolRendezvous _self;
  final $Res Function(DeviceCanvasAgentToolRendezvous) _then;

/// Create a copy of DeviceCanvasAgentToolRendezvous
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? protocolVersion = null,Object? port = null,}) {
  return _then(DeviceCanvasAgentToolRendezvous(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasAgentToolRendezvous extends DeviceCanvasAgentToolRendezvous {
  const _DeviceCanvasAgentToolRendezvous({required this.protocolVersion, required this.port}): super._();
  factory _DeviceCanvasAgentToolRendezvous.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolRendezvousFromJson(json);

@override final  int protocolVersion;
@override final  int port;

/// Create a copy of DeviceCanvasAgentToolRendezvous
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasAgentToolRendezvousCopyWith<_DeviceCanvasAgentToolRendezvous> get copyWith => __$DeviceCanvasAgentToolRendezvousCopyWithImpl<_DeviceCanvasAgentToolRendezvous>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolRendezvousToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasAgentToolRendezvous&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,port);

@override
String toString() {
  return 'DeviceCanvasAgentToolRendezvous(protocolVersion: $protocolVersion, port: $port)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasAgentToolRendezvousCopyWith<$Res> implements $DeviceCanvasAgentToolRendezvousCopyWith<$Res> {
  factory _$DeviceCanvasAgentToolRendezvousCopyWith(_DeviceCanvasAgentToolRendezvous value, $Res Function(_DeviceCanvasAgentToolRendezvous) _then) = __$DeviceCanvasAgentToolRendezvousCopyWithImpl;
@override @useResult
$Res call({
 int protocolVersion, int port
});




}
/// @nodoc
class __$DeviceCanvasAgentToolRendezvousCopyWithImpl<$Res>
    implements _$DeviceCanvasAgentToolRendezvousCopyWith<$Res> {
  __$DeviceCanvasAgentToolRendezvousCopyWithImpl(this._self, this._then);

  final _DeviceCanvasAgentToolRendezvous _self;
  final $Res Function(_DeviceCanvasAgentToolRendezvous) _then;

/// Create a copy of DeviceCanvasAgentToolRendezvous
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? port = null,}) {
  return _then(_DeviceCanvasAgentToolRendezvous(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasAgentToolRegistrationResponse {

 String get bearerToken;
/// Create a copy of DeviceCanvasAgentToolRegistrationResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolRegistrationResponseCopyWith<DeviceCanvasAgentToolRegistrationResponse> get copyWith => _$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl<DeviceCanvasAgentToolRegistrationResponse>(this as DeviceCanvasAgentToolRegistrationResponse, _$identity);

  /// Serializes this DeviceCanvasAgentToolRegistrationResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolRegistrationResponse&&(identical(other.bearerToken, bearerToken) || other.bearerToken == bearerToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bearerToken);

@override
String toString() {
  return 'DeviceCanvasAgentToolRegistrationResponse(bearerToken: $bearerToken)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolRegistrationResponseCopyWith<$Res>  {
  factory $DeviceCanvasAgentToolRegistrationResponseCopyWith(DeviceCanvasAgentToolRegistrationResponse value, $Res Function(DeviceCanvasAgentToolRegistrationResponse) _then) = _$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl;
@useResult
$Res call({
 String bearerToken
});




}
/// @nodoc
class _$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolRegistrationResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolRegistrationResponse _self;
  final $Res Function(DeviceCanvasAgentToolRegistrationResponse) _then;

/// Create a copy of DeviceCanvasAgentToolRegistrationResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bearerToken = null,}) {
  return _then(DeviceCanvasAgentToolRegistrationResponse(
bearerToken: null == bearerToken ? _self.bearerToken : bearerToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasAgentToolRegistrationResponse extends DeviceCanvasAgentToolRegistrationResponse {
  const _DeviceCanvasAgentToolRegistrationResponse({required this.bearerToken}): super._();
  factory _DeviceCanvasAgentToolRegistrationResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolRegistrationResponseFromJson(json);

@override final  String bearerToken;

/// Create a copy of DeviceCanvasAgentToolRegistrationResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasAgentToolRegistrationResponseCopyWith<_DeviceCanvasAgentToolRegistrationResponse> get copyWith => __$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl<_DeviceCanvasAgentToolRegistrationResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolRegistrationResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasAgentToolRegistrationResponse&&(identical(other.bearerToken, bearerToken) || other.bearerToken == bearerToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bearerToken);

@override
String toString() {
  return 'DeviceCanvasAgentToolRegistrationResponse(bearerToken: $bearerToken)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasAgentToolRegistrationResponseCopyWith<$Res> implements $DeviceCanvasAgentToolRegistrationResponseCopyWith<$Res> {
  factory _$DeviceCanvasAgentToolRegistrationResponseCopyWith(_DeviceCanvasAgentToolRegistrationResponse value, $Res Function(_DeviceCanvasAgentToolRegistrationResponse) _then) = __$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl;
@override @useResult
$Res call({
 String bearerToken
});




}
/// @nodoc
class __$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl<$Res>
    implements _$DeviceCanvasAgentToolRegistrationResponseCopyWith<$Res> {
  __$DeviceCanvasAgentToolRegistrationResponseCopyWithImpl(this._self, this._then);

  final _DeviceCanvasAgentToolRegistrationResponse _self;
  final $Res Function(_DeviceCanvasAgentToolRegistrationResponse) _then;

/// Create a copy of DeviceCanvasAgentToolRegistrationResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bearerToken = null,}) {
  return _then(_DeviceCanvasAgentToolRegistrationResponse(
bearerToken: null == bearerToken ? _self.bearerToken : bearerToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasAgentToolListRequest {

 String get backendSessionId;
/// Create a copy of DeviceCanvasAgentToolListRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolListRequestCopyWith<DeviceCanvasAgentToolListRequest> get copyWith => _$DeviceCanvasAgentToolListRequestCopyWithImpl<DeviceCanvasAgentToolListRequest>(this as DeviceCanvasAgentToolListRequest, _$identity);

  /// Serializes this DeviceCanvasAgentToolListRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolListRequest&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,backendSessionId);

@override
String toString() {
  return 'DeviceCanvasAgentToolListRequest(backendSessionId: $backendSessionId)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolListRequestCopyWith<$Res>  {
  factory $DeviceCanvasAgentToolListRequestCopyWith(DeviceCanvasAgentToolListRequest value, $Res Function(DeviceCanvasAgentToolListRequest) _then) = _$DeviceCanvasAgentToolListRequestCopyWithImpl;
@useResult
$Res call({
 String backendSessionId
});




}
/// @nodoc
class _$DeviceCanvasAgentToolListRequestCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolListRequestCopyWith<$Res> {
  _$DeviceCanvasAgentToolListRequestCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolListRequest _self;
  final $Res Function(DeviceCanvasAgentToolListRequest) _then;

/// Create a copy of DeviceCanvasAgentToolListRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? backendSessionId = null,}) {
  return _then(DeviceCanvasAgentToolListRequest(
backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasAgentToolListRequest extends DeviceCanvasAgentToolListRequest {
  const _DeviceCanvasAgentToolListRequest({required this.backendSessionId}): super._();
  factory _DeviceCanvasAgentToolListRequest.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolListRequestFromJson(json);

@override final  String backendSessionId;

/// Create a copy of DeviceCanvasAgentToolListRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasAgentToolListRequestCopyWith<_DeviceCanvasAgentToolListRequest> get copyWith => __$DeviceCanvasAgentToolListRequestCopyWithImpl<_DeviceCanvasAgentToolListRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolListRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasAgentToolListRequest&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,backendSessionId);

@override
String toString() {
  return 'DeviceCanvasAgentToolListRequest(backendSessionId: $backendSessionId)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasAgentToolListRequestCopyWith<$Res> implements $DeviceCanvasAgentToolListRequestCopyWith<$Res> {
  factory _$DeviceCanvasAgentToolListRequestCopyWith(_DeviceCanvasAgentToolListRequest value, $Res Function(_DeviceCanvasAgentToolListRequest) _then) = __$DeviceCanvasAgentToolListRequestCopyWithImpl;
@override @useResult
$Res call({
 String backendSessionId
});




}
/// @nodoc
class __$DeviceCanvasAgentToolListRequestCopyWithImpl<$Res>
    implements _$DeviceCanvasAgentToolListRequestCopyWith<$Res> {
  __$DeviceCanvasAgentToolListRequestCopyWithImpl(this._self, this._then);

  final _DeviceCanvasAgentToolListRequest _self;
  final $Res Function(_DeviceCanvasAgentToolListRequest) _then;

/// Create a copy of DeviceCanvasAgentToolListRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? backendSessionId = null,}) {
  return _then(_DeviceCanvasAgentToolListRequest(
backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasAgentToolMutationRequest {

 String get backendSessionId; String get deviceKey;
/// Create a copy of DeviceCanvasAgentToolMutationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolMutationRequestCopyWith<DeviceCanvasAgentToolMutationRequest> get copyWith => _$DeviceCanvasAgentToolMutationRequestCopyWithImpl<DeviceCanvasAgentToolMutationRequest>(this as DeviceCanvasAgentToolMutationRequest, _$identity);

  /// Serializes this DeviceCanvasAgentToolMutationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolMutationRequest&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,backendSessionId,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolMutationRequest(backendSessionId: $backendSessionId, deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolMutationRequestCopyWith<$Res>  {
  factory $DeviceCanvasAgentToolMutationRequestCopyWith(DeviceCanvasAgentToolMutationRequest value, $Res Function(DeviceCanvasAgentToolMutationRequest) _then) = _$DeviceCanvasAgentToolMutationRequestCopyWithImpl;
@useResult
$Res call({
 String backendSessionId, String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolMutationRequestCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolMutationRequestCopyWith<$Res> {
  _$DeviceCanvasAgentToolMutationRequestCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolMutationRequest _self;
  final $Res Function(DeviceCanvasAgentToolMutationRequest) _then;

/// Create a copy of DeviceCanvasAgentToolMutationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? backendSessionId = null,Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolMutationRequest(
backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasAgentToolMutationRequest extends DeviceCanvasAgentToolMutationRequest {
  const _DeviceCanvasAgentToolMutationRequest({required this.backendSessionId, required this.deviceKey}): super._();
  factory _DeviceCanvasAgentToolMutationRequest.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolMutationRequestFromJson(json);

@override final  String backendSessionId;
@override final  String deviceKey;

/// Create a copy of DeviceCanvasAgentToolMutationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasAgentToolMutationRequestCopyWith<_DeviceCanvasAgentToolMutationRequest> get copyWith => __$DeviceCanvasAgentToolMutationRequestCopyWithImpl<_DeviceCanvasAgentToolMutationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolMutationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasAgentToolMutationRequest&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,backendSessionId,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolMutationRequest(backendSessionId: $backendSessionId, deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasAgentToolMutationRequestCopyWith<$Res> implements $DeviceCanvasAgentToolMutationRequestCopyWith<$Res> {
  factory _$DeviceCanvasAgentToolMutationRequestCopyWith(_DeviceCanvasAgentToolMutationRequest value, $Res Function(_DeviceCanvasAgentToolMutationRequest) _then) = __$DeviceCanvasAgentToolMutationRequestCopyWithImpl;
@override @useResult
$Res call({
 String backendSessionId, String deviceKey
});




}
/// @nodoc
class __$DeviceCanvasAgentToolMutationRequestCopyWithImpl<$Res>
    implements _$DeviceCanvasAgentToolMutationRequestCopyWith<$Res> {
  __$DeviceCanvasAgentToolMutationRequestCopyWithImpl(this._self, this._then);

  final _DeviceCanvasAgentToolMutationRequest _self;
  final $Res Function(_DeviceCanvasAgentToolMutationRequest) _then;

/// Create a copy of DeviceCanvasAgentToolMutationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? backendSessionId = null,Object? deviceKey = null,}) {
  return _then(_DeviceCanvasAgentToolMutationRequest(
backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasAgentToolDevice {

 String get deviceKey; String get platform; String get displayName; String get runtimeDescription; String get modelDescription; DeviceCanvasAgentToolDeviceOwnership get ownership;
/// Create a copy of DeviceCanvasAgentToolDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolDeviceCopyWith<DeviceCanvasAgentToolDevice> get copyWith => _$DeviceCanvasAgentToolDeviceCopyWithImpl<DeviceCanvasAgentToolDevice>(this as DeviceCanvasAgentToolDevice, _$identity);

  /// Serializes this DeviceCanvasAgentToolDevice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolDevice&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.ownership, ownership) || other.ownership == ownership));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,platform,displayName,runtimeDescription,modelDescription,ownership);

@override
String toString() {
  return 'DeviceCanvasAgentToolDevice(deviceKey: $deviceKey, platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, ownership: $ownership)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolDeviceCopyWith<$Res>  {
  factory $DeviceCanvasAgentToolDeviceCopyWith(DeviceCanvasAgentToolDevice value, $Res Function(DeviceCanvasAgentToolDevice) _then) = _$DeviceCanvasAgentToolDeviceCopyWithImpl;
@useResult
$Res call({
 String deviceKey, String platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasAgentToolDeviceOwnership ownership
});




}
/// @nodoc
class _$DeviceCanvasAgentToolDeviceCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolDeviceCopyWith<$Res> {
  _$DeviceCanvasAgentToolDeviceCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolDevice _self;
  final $Res Function(DeviceCanvasAgentToolDevice) _then;

/// Create a copy of DeviceCanvasAgentToolDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceKey = null,Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? ownership = null,}) {
  return _then(DeviceCanvasAgentToolDevice(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,ownership: null == ownership ? _self.ownership : ownership // ignore: cast_nullable_to_non_nullable
as DeviceCanvasAgentToolDeviceOwnership,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasAgentToolDevice extends DeviceCanvasAgentToolDevice {
  const _DeviceCanvasAgentToolDevice({required this.deviceKey, required this.platform, required this.displayName, required this.runtimeDescription, required this.modelDescription, required this.ownership}): super._();
  factory _DeviceCanvasAgentToolDevice.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolDeviceFromJson(json);

@override final  String deviceKey;
@override final  String platform;
@override final  String displayName;
@override final  String runtimeDescription;
@override final  String modelDescription;
@override final  DeviceCanvasAgentToolDeviceOwnership ownership;

/// Create a copy of DeviceCanvasAgentToolDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasAgentToolDeviceCopyWith<_DeviceCanvasAgentToolDevice> get copyWith => __$DeviceCanvasAgentToolDeviceCopyWithImpl<_DeviceCanvasAgentToolDevice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolDeviceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasAgentToolDevice&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.ownership, ownership) || other.ownership == ownership));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,platform,displayName,runtimeDescription,modelDescription,ownership);

@override
String toString() {
  return 'DeviceCanvasAgentToolDevice(deviceKey: $deviceKey, platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, ownership: $ownership)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasAgentToolDeviceCopyWith<$Res> implements $DeviceCanvasAgentToolDeviceCopyWith<$Res> {
  factory _$DeviceCanvasAgentToolDeviceCopyWith(_DeviceCanvasAgentToolDevice value, $Res Function(_DeviceCanvasAgentToolDevice) _then) = __$DeviceCanvasAgentToolDeviceCopyWithImpl;
@override @useResult
$Res call({
 String deviceKey, String platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasAgentToolDeviceOwnership ownership
});




}
/// @nodoc
class __$DeviceCanvasAgentToolDeviceCopyWithImpl<$Res>
    implements _$DeviceCanvasAgentToolDeviceCopyWith<$Res> {
  __$DeviceCanvasAgentToolDeviceCopyWithImpl(this._self, this._then);

  final _DeviceCanvasAgentToolDevice _self;
  final $Res Function(_DeviceCanvasAgentToolDevice) _then;

/// Create a copy of DeviceCanvasAgentToolDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? ownership = null,}) {
  return _then(_DeviceCanvasAgentToolDevice(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,ownership: null == ownership ? _self.ownership : ownership // ignore: cast_nullable_to_non_nullable
as DeviceCanvasAgentToolDeviceOwnership,
  ));
}


}

DeviceCanvasAgentToolResponse _$DeviceCanvasAgentToolResponseFromJson(
  Map<String, dynamic> json
) {
        switch (json['outcome']) {
                  case 'listed':
          return DeviceCanvasAgentToolListedResponse.fromJson(
            json
          );
                case 'claimed':
          return DeviceCanvasAgentToolClaimedResponse.fromJson(
            json
          );
                case 'alreadyOwned':
          return DeviceCanvasAgentToolAlreadyOwnedResponse.fromJson(
            json
          );
                case 'released':
          return DeviceCanvasAgentToolReleasedResponse.fromJson(
            json
          );
                case 'alreadyReleased':
          return DeviceCanvasAgentToolAlreadyReleasedResponse.fromJson(
            json
          );
                case 'conflict':
          return DeviceCanvasAgentToolConflictResponse.fromJson(
            json
          );
                case 'deviceUnavailable':
          return DeviceCanvasAgentToolDeviceUnavailableResponse.fromJson(
            json
          );
                case 'sessionUnavailable':
          return DeviceCanvasAgentToolSessionUnavailableResponse.fromJson(
            json
          );
                case 'integrationUnavailable':
          return DeviceCanvasAgentToolIntegrationUnavailableResponse.fromJson(
            json
          );
                case 'bridgeUnavailable':
          return DeviceCanvasAgentToolBridgeUnavailableResponse.fromJson(
            json
          );
                case 'invalidRequest':
          return DeviceCanvasAgentToolInvalidRequestResponse.fromJson(
            json
          );
                case 'internalError':
          return DeviceCanvasAgentToolInternalErrorResponse.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'outcome',
  'DeviceCanvasAgentToolResponse',
  'Invalid union type "${json['outcome']}"!'
);
        }
      
}

/// @nodoc
mixin _$DeviceCanvasAgentToolResponse {



  /// Serializes this DeviceCanvasAgentToolResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse()';
}


}

/// @nodoc
class $DeviceCanvasAgentToolResponseCopyWith<$Res>  {
$DeviceCanvasAgentToolResponseCopyWith(DeviceCanvasAgentToolResponse _, $Res Function(DeviceCanvasAgentToolResponse) __);
}



/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolListedResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolListedResponse({required  List<DeviceCanvasAgentToolDevice> devices, required this.truncated,  String? $type}): _devices = devices,$type = $type ?? 'listed';
  factory DeviceCanvasAgentToolListedResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolListedResponseFromJson(json);

 final  List<DeviceCanvasAgentToolDevice> _devices;
 List<DeviceCanvasAgentToolDevice> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

 final  bool truncated;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolListedResponseCopyWith<DeviceCanvasAgentToolListedResponse> get copyWith => _$DeviceCanvasAgentToolListedResponseCopyWithImpl<DeviceCanvasAgentToolListedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolListedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolListedResponse&&const DeepCollectionEquality().equals(other._devices, _devices)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_devices),truncated);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.listed(devices: $devices, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolListedResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolListedResponseCopyWith(DeviceCanvasAgentToolListedResponse value, $Res Function(DeviceCanvasAgentToolListedResponse) _then) = _$DeviceCanvasAgentToolListedResponseCopyWithImpl;
@useResult
$Res call({
 List<DeviceCanvasAgentToolDevice> devices, bool truncated
});




}
/// @nodoc
class _$DeviceCanvasAgentToolListedResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolListedResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolListedResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolListedResponse _self;
  final $Res Function(DeviceCanvasAgentToolListedResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? devices = null,Object? truncated = null,}) {
  return _then(DeviceCanvasAgentToolListedResponse(
devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<DeviceCanvasAgentToolDevice>,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolClaimedResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolClaimedResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'claimed';
  factory DeviceCanvasAgentToolClaimedResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolClaimedResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolClaimedResponseCopyWith<DeviceCanvasAgentToolClaimedResponse> get copyWith => _$DeviceCanvasAgentToolClaimedResponseCopyWithImpl<DeviceCanvasAgentToolClaimedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolClaimedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolClaimedResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.claimed(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolClaimedResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolClaimedResponseCopyWith(DeviceCanvasAgentToolClaimedResponse value, $Res Function(DeviceCanvasAgentToolClaimedResponse) _then) = _$DeviceCanvasAgentToolClaimedResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolClaimedResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolClaimedResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolClaimedResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolClaimedResponse _self;
  final $Res Function(DeviceCanvasAgentToolClaimedResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolClaimedResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolAlreadyOwnedResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolAlreadyOwnedResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'alreadyOwned';
  factory DeviceCanvasAgentToolAlreadyOwnedResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolAlreadyOwnedResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolAlreadyOwnedResponseCopyWith<DeviceCanvasAgentToolAlreadyOwnedResponse> get copyWith => _$DeviceCanvasAgentToolAlreadyOwnedResponseCopyWithImpl<DeviceCanvasAgentToolAlreadyOwnedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolAlreadyOwnedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolAlreadyOwnedResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.alreadyOwned(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolAlreadyOwnedResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolAlreadyOwnedResponseCopyWith(DeviceCanvasAgentToolAlreadyOwnedResponse value, $Res Function(DeviceCanvasAgentToolAlreadyOwnedResponse) _then) = _$DeviceCanvasAgentToolAlreadyOwnedResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolAlreadyOwnedResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolAlreadyOwnedResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolAlreadyOwnedResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolAlreadyOwnedResponse _self;
  final $Res Function(DeviceCanvasAgentToolAlreadyOwnedResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolAlreadyOwnedResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolReleasedResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolReleasedResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'released';
  factory DeviceCanvasAgentToolReleasedResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolReleasedResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolReleasedResponseCopyWith<DeviceCanvasAgentToolReleasedResponse> get copyWith => _$DeviceCanvasAgentToolReleasedResponseCopyWithImpl<DeviceCanvasAgentToolReleasedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolReleasedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolReleasedResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.released(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolReleasedResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolReleasedResponseCopyWith(DeviceCanvasAgentToolReleasedResponse value, $Res Function(DeviceCanvasAgentToolReleasedResponse) _then) = _$DeviceCanvasAgentToolReleasedResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolReleasedResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolReleasedResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolReleasedResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolReleasedResponse _self;
  final $Res Function(DeviceCanvasAgentToolReleasedResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolReleasedResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolAlreadyReleasedResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolAlreadyReleasedResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'alreadyReleased';
  factory DeviceCanvasAgentToolAlreadyReleasedResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolAlreadyReleasedResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolAlreadyReleasedResponseCopyWith<DeviceCanvasAgentToolAlreadyReleasedResponse> get copyWith => _$DeviceCanvasAgentToolAlreadyReleasedResponseCopyWithImpl<DeviceCanvasAgentToolAlreadyReleasedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolAlreadyReleasedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolAlreadyReleasedResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.alreadyReleased(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolAlreadyReleasedResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolAlreadyReleasedResponseCopyWith(DeviceCanvasAgentToolAlreadyReleasedResponse value, $Res Function(DeviceCanvasAgentToolAlreadyReleasedResponse) _then) = _$DeviceCanvasAgentToolAlreadyReleasedResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolAlreadyReleasedResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolAlreadyReleasedResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolAlreadyReleasedResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolAlreadyReleasedResponse _self;
  final $Res Function(DeviceCanvasAgentToolAlreadyReleasedResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolAlreadyReleasedResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolConflictResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolConflictResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'conflict';
  factory DeviceCanvasAgentToolConflictResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolConflictResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolConflictResponseCopyWith<DeviceCanvasAgentToolConflictResponse> get copyWith => _$DeviceCanvasAgentToolConflictResponseCopyWithImpl<DeviceCanvasAgentToolConflictResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolConflictResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolConflictResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.conflict(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolConflictResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolConflictResponseCopyWith(DeviceCanvasAgentToolConflictResponse value, $Res Function(DeviceCanvasAgentToolConflictResponse) _then) = _$DeviceCanvasAgentToolConflictResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolConflictResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolConflictResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolConflictResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolConflictResponse _self;
  final $Res Function(DeviceCanvasAgentToolConflictResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolConflictResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolDeviceUnavailableResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolDeviceUnavailableResponse({required this.deviceKey,  String? $type}): $type = $type ?? 'deviceUnavailable';
  factory DeviceCanvasAgentToolDeviceUnavailableResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolDeviceUnavailableResponseFromJson(json);

 final  String deviceKey;

@JsonKey(name: 'outcome')
final String $type;


/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasAgentToolDeviceUnavailableResponseCopyWith<DeviceCanvasAgentToolDeviceUnavailableResponse> get copyWith => _$DeviceCanvasAgentToolDeviceUnavailableResponseCopyWithImpl<DeviceCanvasAgentToolDeviceUnavailableResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolDeviceUnavailableResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolDeviceUnavailableResponse&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey);

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.deviceUnavailable(deviceKey: $deviceKey)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasAgentToolDeviceUnavailableResponseCopyWith<$Res> implements $DeviceCanvasAgentToolResponseCopyWith<$Res> {
  factory $DeviceCanvasAgentToolDeviceUnavailableResponseCopyWith(DeviceCanvasAgentToolDeviceUnavailableResponse value, $Res Function(DeviceCanvasAgentToolDeviceUnavailableResponse) _then) = _$DeviceCanvasAgentToolDeviceUnavailableResponseCopyWithImpl;
@useResult
$Res call({
 String deviceKey
});




}
/// @nodoc
class _$DeviceCanvasAgentToolDeviceUnavailableResponseCopyWithImpl<$Res>
    implements $DeviceCanvasAgentToolDeviceUnavailableResponseCopyWith<$Res> {
  _$DeviceCanvasAgentToolDeviceUnavailableResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasAgentToolDeviceUnavailableResponse _self;
  final $Res Function(DeviceCanvasAgentToolDeviceUnavailableResponse) _then;

/// Create a copy of DeviceCanvasAgentToolResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,}) {
  return _then(DeviceCanvasAgentToolDeviceUnavailableResponse(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolSessionUnavailableResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolSessionUnavailableResponse({ String? $type}): $type = $type ?? 'sessionUnavailable';
  factory DeviceCanvasAgentToolSessionUnavailableResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolSessionUnavailableResponseFromJson(json);



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolSessionUnavailableResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolSessionUnavailableResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.sessionUnavailable()';
}


}




/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolIntegrationUnavailableResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolIntegrationUnavailableResponse({ String? $type}): $type = $type ?? 'integrationUnavailable';
  factory DeviceCanvasAgentToolIntegrationUnavailableResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolIntegrationUnavailableResponseFromJson(json);



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolIntegrationUnavailableResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolIntegrationUnavailableResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.integrationUnavailable()';
}


}




/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolBridgeUnavailableResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolBridgeUnavailableResponse({ String? $type}): $type = $type ?? 'bridgeUnavailable';
  factory DeviceCanvasAgentToolBridgeUnavailableResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolBridgeUnavailableResponseFromJson(json);



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolBridgeUnavailableResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolBridgeUnavailableResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.bridgeUnavailable()';
}


}




/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolInvalidRequestResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolInvalidRequestResponse({ String? $type}): $type = $type ?? 'invalidRequest';
  factory DeviceCanvasAgentToolInvalidRequestResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolInvalidRequestResponseFromJson(json);



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolInvalidRequestResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolInvalidRequestResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.invalidRequest()';
}


}




/// @nodoc
@JsonSerializable()

class DeviceCanvasAgentToolInternalErrorResponse implements DeviceCanvasAgentToolResponse {
  const DeviceCanvasAgentToolInternalErrorResponse({ String? $type}): $type = $type ?? 'internalError';
  factory DeviceCanvasAgentToolInternalErrorResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolInternalErrorResponseFromJson(json);



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasAgentToolInternalErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasAgentToolInternalErrorResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasAgentToolResponse.internalError()';
}


}




// dart format on
