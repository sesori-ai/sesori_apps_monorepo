// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_canvas_client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceCanvasSessionStatusRequest {

 String get sessionId;
/// Create a copy of DeviceCanvasSessionStatusRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasSessionStatusRequestCopyWith<DeviceCanvasSessionStatusRequest> get copyWith => _$DeviceCanvasSessionStatusRequestCopyWithImpl<DeviceCanvasSessionStatusRequest>(this as DeviceCanvasSessionStatusRequest, _$identity);

  /// Serializes this DeviceCanvasSessionStatusRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasSessionStatusRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'DeviceCanvasSessionStatusRequest(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasSessionStatusRequestCopyWith<$Res>  {
  factory $DeviceCanvasSessionStatusRequestCopyWith(DeviceCanvasSessionStatusRequest value, $Res Function(DeviceCanvasSessionStatusRequest) _then) = _$DeviceCanvasSessionStatusRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$DeviceCanvasSessionStatusRequestCopyWithImpl<$Res>
    implements $DeviceCanvasSessionStatusRequestCopyWith<$Res> {
  _$DeviceCanvasSessionStatusRequestCopyWithImpl(this._self, this._then);

  final DeviceCanvasSessionStatusRequest _self;
  final $Res Function(DeviceCanvasSessionStatusRequest) _then;

/// Create a copy of DeviceCanvasSessionStatusRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(DeviceCanvasSessionStatusRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasSessionStatusRequest extends DeviceCanvasSessionStatusRequest {
  const _DeviceCanvasSessionStatusRequest({required this.sessionId}): super._();
  factory _DeviceCanvasSessionStatusRequest.fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusRequestFromJson(json);

@override final  String sessionId;

/// Create a copy of DeviceCanvasSessionStatusRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasSessionStatusRequestCopyWith<_DeviceCanvasSessionStatusRequest> get copyWith => __$DeviceCanvasSessionStatusRequestCopyWithImpl<_DeviceCanvasSessionStatusRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasSessionStatusRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasSessionStatusRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'DeviceCanvasSessionStatusRequest(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasSessionStatusRequestCopyWith<$Res> implements $DeviceCanvasSessionStatusRequestCopyWith<$Res> {
  factory _$DeviceCanvasSessionStatusRequestCopyWith(_DeviceCanvasSessionStatusRequest value, $Res Function(_DeviceCanvasSessionStatusRequest) _then) = __$DeviceCanvasSessionStatusRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$DeviceCanvasSessionStatusRequestCopyWithImpl<$Res>
    implements _$DeviceCanvasSessionStatusRequestCopyWith<$Res> {
  __$DeviceCanvasSessionStatusRequestCopyWithImpl(this._self, this._then);

  final _DeviceCanvasSessionStatusRequest _self;
  final $Res Function(_DeviceCanvasSessionStatusRequest) _then;

/// Create a copy of DeviceCanvasSessionStatusRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_DeviceCanvasSessionStatusRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasClaimRequest {

 String get expectedBridgeId; String get sessionId; String get deviceKey; bool get reassign; String? get expectedOwnerSessionId; int? get expectedClaimRevision;
/// Create a copy of DeviceCanvasClaimRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimRequestCopyWith<DeviceCanvasClaimRequest> get copyWith => _$DeviceCanvasClaimRequestCopyWithImpl<DeviceCanvasClaimRequest>(this as DeviceCanvasClaimRequest, _$identity);

  /// Serializes this DeviceCanvasClaimRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimRequest&&(identical(other.expectedBridgeId, expectedBridgeId) || other.expectedBridgeId == expectedBridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.reassign, reassign) || other.reassign == reassign)&&(identical(other.expectedOwnerSessionId, expectedOwnerSessionId) || other.expectedOwnerSessionId == expectedOwnerSessionId)&&(identical(other.expectedClaimRevision, expectedClaimRevision) || other.expectedClaimRevision == expectedClaimRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expectedBridgeId,sessionId,deviceKey,reassign,expectedOwnerSessionId,expectedClaimRevision);

@override
String toString() {
  return 'DeviceCanvasClaimRequest(expectedBridgeId: $expectedBridgeId, sessionId: $sessionId, deviceKey: $deviceKey, reassign: $reassign, expectedOwnerSessionId: $expectedOwnerSessionId, expectedClaimRevision: $expectedClaimRevision)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimRequestCopyWith<$Res>  {
  factory $DeviceCanvasClaimRequestCopyWith(DeviceCanvasClaimRequest value, $Res Function(DeviceCanvasClaimRequest) _then) = _$DeviceCanvasClaimRequestCopyWithImpl;
@useResult
$Res call({
 String expectedBridgeId, String sessionId, String deviceKey, bool reassign, String? expectedOwnerSessionId, int? expectedClaimRevision
});




}
/// @nodoc
class _$DeviceCanvasClaimRequestCopyWithImpl<$Res>
    implements $DeviceCanvasClaimRequestCopyWith<$Res> {
  _$DeviceCanvasClaimRequestCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimRequest _self;
  final $Res Function(DeviceCanvasClaimRequest) _then;

/// Create a copy of DeviceCanvasClaimRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? expectedBridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? reassign = null,Object? expectedOwnerSessionId = freezed,Object? expectedClaimRevision = freezed,}) {
  return _then(DeviceCanvasClaimRequest(
expectedBridgeId: null == expectedBridgeId ? _self.expectedBridgeId : expectedBridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,reassign: null == reassign ? _self.reassign : reassign // ignore: cast_nullable_to_non_nullable
as bool,expectedOwnerSessionId: freezed == expectedOwnerSessionId ? _self.expectedOwnerSessionId : expectedOwnerSessionId // ignore: cast_nullable_to_non_nullable
as String?,expectedClaimRevision: freezed == expectedClaimRevision ? _self.expectedClaimRevision : expectedClaimRevision // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClaimRequest extends DeviceCanvasClaimRequest {
  const _DeviceCanvasClaimRequest({required this.expectedBridgeId, required this.sessionId, required this.deviceKey, this.reassign = false, required this.expectedOwnerSessionId, required this.expectedClaimRevision}): super._();
  factory _DeviceCanvasClaimRequest.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimRequestFromJson(json);

@override final  String expectedBridgeId;
@override final  String sessionId;
@override final  String deviceKey;
@override@JsonKey() final  bool reassign;
@override final  String? expectedOwnerSessionId;
@override final  int? expectedClaimRevision;

/// Create a copy of DeviceCanvasClaimRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClaimRequestCopyWith<_DeviceCanvasClaimRequest> get copyWith => __$DeviceCanvasClaimRequestCopyWithImpl<_DeviceCanvasClaimRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClaimRequest&&(identical(other.expectedBridgeId, expectedBridgeId) || other.expectedBridgeId == expectedBridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.reassign, reassign) || other.reassign == reassign)&&(identical(other.expectedOwnerSessionId, expectedOwnerSessionId) || other.expectedOwnerSessionId == expectedOwnerSessionId)&&(identical(other.expectedClaimRevision, expectedClaimRevision) || other.expectedClaimRevision == expectedClaimRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expectedBridgeId,sessionId,deviceKey,reassign,expectedOwnerSessionId,expectedClaimRevision);

@override
String toString() {
  return 'DeviceCanvasClaimRequest(expectedBridgeId: $expectedBridgeId, sessionId: $sessionId, deviceKey: $deviceKey, reassign: $reassign, expectedOwnerSessionId: $expectedOwnerSessionId, expectedClaimRevision: $expectedClaimRevision)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClaimRequestCopyWith<$Res> implements $DeviceCanvasClaimRequestCopyWith<$Res> {
  factory _$DeviceCanvasClaimRequestCopyWith(_DeviceCanvasClaimRequest value, $Res Function(_DeviceCanvasClaimRequest) _then) = __$DeviceCanvasClaimRequestCopyWithImpl;
@override @useResult
$Res call({
 String expectedBridgeId, String sessionId, String deviceKey, bool reassign, String? expectedOwnerSessionId, int? expectedClaimRevision
});




}
/// @nodoc
class __$DeviceCanvasClaimRequestCopyWithImpl<$Res>
    implements _$DeviceCanvasClaimRequestCopyWith<$Res> {
  __$DeviceCanvasClaimRequestCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClaimRequest _self;
  final $Res Function(_DeviceCanvasClaimRequest) _then;

/// Create a copy of DeviceCanvasClaimRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? expectedBridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? reassign = null,Object? expectedOwnerSessionId = freezed,Object? expectedClaimRevision = freezed,}) {
  return _then(_DeviceCanvasClaimRequest(
expectedBridgeId: null == expectedBridgeId ? _self.expectedBridgeId : expectedBridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,reassign: null == reassign ? _self.reassign : reassign // ignore: cast_nullable_to_non_nullable
as bool,expectedOwnerSessionId: freezed == expectedOwnerSessionId ? _self.expectedOwnerSessionId : expectedOwnerSessionId // ignore: cast_nullable_to_non_nullable
as String?,expectedClaimRevision: freezed == expectedClaimRevision ? _self.expectedClaimRevision : expectedClaimRevision // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasReleaseRequest {

 String get expectedBridgeId; String get sessionId; String get deviceKey; int get expectedClaimRevision;
/// Create a copy of DeviceCanvasReleaseRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasReleaseRequestCopyWith<DeviceCanvasReleaseRequest> get copyWith => _$DeviceCanvasReleaseRequestCopyWithImpl<DeviceCanvasReleaseRequest>(this as DeviceCanvasReleaseRequest, _$identity);

  /// Serializes this DeviceCanvasReleaseRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasReleaseRequest&&(identical(other.expectedBridgeId, expectedBridgeId) || other.expectedBridgeId == expectedBridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.expectedClaimRevision, expectedClaimRevision) || other.expectedClaimRevision == expectedClaimRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expectedBridgeId,sessionId,deviceKey,expectedClaimRevision);

@override
String toString() {
  return 'DeviceCanvasReleaseRequest(expectedBridgeId: $expectedBridgeId, sessionId: $sessionId, deviceKey: $deviceKey, expectedClaimRevision: $expectedClaimRevision)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasReleaseRequestCopyWith<$Res>  {
  factory $DeviceCanvasReleaseRequestCopyWith(DeviceCanvasReleaseRequest value, $Res Function(DeviceCanvasReleaseRequest) _then) = _$DeviceCanvasReleaseRequestCopyWithImpl;
@useResult
$Res call({
 String expectedBridgeId, String sessionId, String deviceKey, int expectedClaimRevision
});




}
/// @nodoc
class _$DeviceCanvasReleaseRequestCopyWithImpl<$Res>
    implements $DeviceCanvasReleaseRequestCopyWith<$Res> {
  _$DeviceCanvasReleaseRequestCopyWithImpl(this._self, this._then);

  final DeviceCanvasReleaseRequest _self;
  final $Res Function(DeviceCanvasReleaseRequest) _then;

/// Create a copy of DeviceCanvasReleaseRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? expectedBridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? expectedClaimRevision = null,}) {
  return _then(DeviceCanvasReleaseRequest(
expectedBridgeId: null == expectedBridgeId ? _self.expectedBridgeId : expectedBridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,expectedClaimRevision: null == expectedClaimRevision ? _self.expectedClaimRevision : expectedClaimRevision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasReleaseRequest extends DeviceCanvasReleaseRequest {
  const _DeviceCanvasReleaseRequest({required this.expectedBridgeId, required this.sessionId, required this.deviceKey, required this.expectedClaimRevision}): super._();
  factory _DeviceCanvasReleaseRequest.fromJson(Map<String, dynamic> json) => _$DeviceCanvasReleaseRequestFromJson(json);

@override final  String expectedBridgeId;
@override final  String sessionId;
@override final  String deviceKey;
@override final  int expectedClaimRevision;

/// Create a copy of DeviceCanvasReleaseRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasReleaseRequestCopyWith<_DeviceCanvasReleaseRequest> get copyWith => __$DeviceCanvasReleaseRequestCopyWithImpl<_DeviceCanvasReleaseRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasReleaseRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasReleaseRequest&&(identical(other.expectedBridgeId, expectedBridgeId) || other.expectedBridgeId == expectedBridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.expectedClaimRevision, expectedClaimRevision) || other.expectedClaimRevision == expectedClaimRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expectedBridgeId,sessionId,deviceKey,expectedClaimRevision);

@override
String toString() {
  return 'DeviceCanvasReleaseRequest(expectedBridgeId: $expectedBridgeId, sessionId: $sessionId, deviceKey: $deviceKey, expectedClaimRevision: $expectedClaimRevision)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasReleaseRequestCopyWith<$Res> implements $DeviceCanvasReleaseRequestCopyWith<$Res> {
  factory _$DeviceCanvasReleaseRequestCopyWith(_DeviceCanvasReleaseRequest value, $Res Function(_DeviceCanvasReleaseRequest) _then) = __$DeviceCanvasReleaseRequestCopyWithImpl;
@override @useResult
$Res call({
 String expectedBridgeId, String sessionId, String deviceKey, int expectedClaimRevision
});




}
/// @nodoc
class __$DeviceCanvasReleaseRequestCopyWithImpl<$Res>
    implements _$DeviceCanvasReleaseRequestCopyWith<$Res> {
  __$DeviceCanvasReleaseRequestCopyWithImpl(this._self, this._then);

  final _DeviceCanvasReleaseRequest _self;
  final $Res Function(_DeviceCanvasReleaseRequest) _then;

/// Create a copy of DeviceCanvasReleaseRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? expectedBridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? expectedClaimRevision = null,}) {
  return _then(_DeviceCanvasReleaseRequest(
expectedBridgeId: null == expectedBridgeId ? _self.expectedBridgeId : expectedBridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,expectedClaimRevision: null == expectedClaimRevision ? _self.expectedClaimRevision : expectedClaimRevision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasClientCapabilities {

 bool get localView; bool get remoteVideo; bool get remoteControl; bool get input;
/// Create a copy of DeviceCanvasClientCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClientCapabilitiesCopyWith<DeviceCanvasClientCapabilities> get copyWith => _$DeviceCanvasClientCapabilitiesCopyWithImpl<DeviceCanvasClientCapabilities>(this as DeviceCanvasClientCapabilities, _$identity);

  /// Serializes this DeviceCanvasClientCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClientCapabilities&&(identical(other.localView, localView) || other.localView == localView)&&(identical(other.remoteVideo, remoteVideo) || other.remoteVideo == remoteVideo)&&(identical(other.remoteControl, remoteControl) || other.remoteControl == remoteControl)&&(identical(other.input, input) || other.input == input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localView,remoteVideo,remoteControl,input);

@override
String toString() {
  return 'DeviceCanvasClientCapabilities(localView: $localView, remoteVideo: $remoteVideo, remoteControl: $remoteControl, input: $input)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClientCapabilitiesCopyWith<$Res>  {
  factory $DeviceCanvasClientCapabilitiesCopyWith(DeviceCanvasClientCapabilities value, $Res Function(DeviceCanvasClientCapabilities) _then) = _$DeviceCanvasClientCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool localView, bool remoteVideo, bool remoteControl, bool input
});




}
/// @nodoc
class _$DeviceCanvasClientCapabilitiesCopyWithImpl<$Res>
    implements $DeviceCanvasClientCapabilitiesCopyWith<$Res> {
  _$DeviceCanvasClientCapabilitiesCopyWithImpl(this._self, this._then);

  final DeviceCanvasClientCapabilities _self;
  final $Res Function(DeviceCanvasClientCapabilities) _then;

/// Create a copy of DeviceCanvasClientCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? localView = null,Object? remoteVideo = null,Object? remoteControl = null,Object? input = null,}) {
  return _then(DeviceCanvasClientCapabilities(
localView: null == localView ? _self.localView : localView // ignore: cast_nullable_to_non_nullable
as bool,remoteVideo: null == remoteVideo ? _self.remoteVideo : remoteVideo // ignore: cast_nullable_to_non_nullable
as bool,remoteControl: null == remoteControl ? _self.remoteControl : remoteControl // ignore: cast_nullable_to_non_nullable
as bool,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClientCapabilities implements DeviceCanvasClientCapabilities {
  const _DeviceCanvasClientCapabilities({this.localView = false, this.remoteVideo = false, this.remoteControl = false, this.input = false});
  factory _DeviceCanvasClientCapabilities.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientCapabilitiesFromJson(json);

@override@JsonKey() final  bool localView;
@override@JsonKey() final  bool remoteVideo;
@override@JsonKey() final  bool remoteControl;
@override@JsonKey() final  bool input;

/// Create a copy of DeviceCanvasClientCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClientCapabilitiesCopyWith<_DeviceCanvasClientCapabilities> get copyWith => __$DeviceCanvasClientCapabilitiesCopyWithImpl<_DeviceCanvasClientCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClientCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClientCapabilities&&(identical(other.localView, localView) || other.localView == localView)&&(identical(other.remoteVideo, remoteVideo) || other.remoteVideo == remoteVideo)&&(identical(other.remoteControl, remoteControl) || other.remoteControl == remoteControl)&&(identical(other.input, input) || other.input == input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localView,remoteVideo,remoteControl,input);

@override
String toString() {
  return 'DeviceCanvasClientCapabilities(localView: $localView, remoteVideo: $remoteVideo, remoteControl: $remoteControl, input: $input)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClientCapabilitiesCopyWith<$Res> implements $DeviceCanvasClientCapabilitiesCopyWith<$Res> {
  factory _$DeviceCanvasClientCapabilitiesCopyWith(_DeviceCanvasClientCapabilities value, $Res Function(_DeviceCanvasClientCapabilities) _then) = __$DeviceCanvasClientCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool localView, bool remoteVideo, bool remoteControl, bool input
});




}
/// @nodoc
class __$DeviceCanvasClientCapabilitiesCopyWithImpl<$Res>
    implements _$DeviceCanvasClientCapabilitiesCopyWith<$Res> {
  __$DeviceCanvasClientCapabilitiesCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClientCapabilities _self;
  final $Res Function(_DeviceCanvasClientCapabilities) _then;

/// Create a copy of DeviceCanvasClientCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? localView = null,Object? remoteVideo = null,Object? remoteControl = null,Object? input = null,}) {
  return _then(_DeviceCanvasClientCapabilities(
localView: null == localView ? _self.localView : localView // ignore: cast_nullable_to_non_nullable
as bool,remoteVideo: null == remoteVideo ? _self.remoteVideo : remoteVideo // ignore: cast_nullable_to_non_nullable
as bool,remoteControl: null == remoteControl ? _self.remoteControl : remoteControl // ignore: cast_nullable_to_non_nullable
as bool,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasClientDimensions {

 int get width; int get height;
/// Create a copy of DeviceCanvasClientDimensions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClientDimensionsCopyWith<DeviceCanvasClientDimensions> get copyWith => _$DeviceCanvasClientDimensionsCopyWithImpl<DeviceCanvasClientDimensions>(this as DeviceCanvasClientDimensions, _$identity);

  /// Serializes this DeviceCanvasClientDimensions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClientDimensions&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'DeviceCanvasClientDimensions(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClientDimensionsCopyWith<$Res>  {
  factory $DeviceCanvasClientDimensionsCopyWith(DeviceCanvasClientDimensions value, $Res Function(DeviceCanvasClientDimensions) _then) = _$DeviceCanvasClientDimensionsCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$DeviceCanvasClientDimensionsCopyWithImpl<$Res>
    implements $DeviceCanvasClientDimensionsCopyWith<$Res> {
  _$DeviceCanvasClientDimensionsCopyWithImpl(this._self, this._then);

  final DeviceCanvasClientDimensions _self;
  final $Res Function(DeviceCanvasClientDimensions) _then;

/// Create a copy of DeviceCanvasClientDimensions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,}) {
  return _then(DeviceCanvasClientDimensions(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClientDimensions implements DeviceCanvasClientDimensions {
  const _DeviceCanvasClientDimensions({required this.width, required this.height});
  factory _DeviceCanvasClientDimensions.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDimensionsFromJson(json);

@override final  int width;
@override final  int height;

/// Create a copy of DeviceCanvasClientDimensions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClientDimensionsCopyWith<_DeviceCanvasClientDimensions> get copyWith => __$DeviceCanvasClientDimensionsCopyWithImpl<_DeviceCanvasClientDimensions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClientDimensionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClientDimensions&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'DeviceCanvasClientDimensions(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClientDimensionsCopyWith<$Res> implements $DeviceCanvasClientDimensionsCopyWith<$Res> {
  factory _$DeviceCanvasClientDimensionsCopyWith(_DeviceCanvasClientDimensions value, $Res Function(_DeviceCanvasClientDimensions) _then) = __$DeviceCanvasClientDimensionsCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class __$DeviceCanvasClientDimensionsCopyWithImpl<$Res>
    implements _$DeviceCanvasClientDimensionsCopyWith<$Res> {
  __$DeviceCanvasClientDimensionsCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClientDimensions _self;
  final $Res Function(_DeviceCanvasClientDimensions) _then;

/// Create a copy of DeviceCanvasClientDimensions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(_DeviceCanvasClientDimensions(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasClientDescriptor {

@JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) DeviceCanvasClientPlatform get platform; String get displayName; String get runtimeDescription; String get modelDescription; DeviceCanvasClientDimensions? get dimensions;@JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown) DeviceCanvasClientOrientation? get orientation; DeviceCanvasClientCapabilities get capabilities;
/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClientDescriptorCopyWith<DeviceCanvasClientDescriptor> get copyWith => _$DeviceCanvasClientDescriptorCopyWithImpl<DeviceCanvasClientDescriptor>(this as DeviceCanvasClientDescriptor, _$identity);

  /// Serializes this DeviceCanvasClientDescriptor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClientDescriptor&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.dimensions, dimensions) || other.dimensions == dimensions)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platform,displayName,runtimeDescription,modelDescription,dimensions,orientation,capabilities);

@override
String toString() {
  return 'DeviceCanvasClientDescriptor(platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, dimensions: $dimensions, orientation: $orientation, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClientDescriptorCopyWith<$Res>  {
  factory $DeviceCanvasClientDescriptorCopyWith(DeviceCanvasClientDescriptor value, $Res Function(DeviceCanvasClientDescriptor) _then) = _$DeviceCanvasClientDescriptorCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) DeviceCanvasClientPlatform platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasClientDimensions? dimensions,@JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown) DeviceCanvasClientOrientation? orientation, DeviceCanvasClientCapabilities capabilities
});


$DeviceCanvasClientDimensionsCopyWith<$Res>? get dimensions;$DeviceCanvasClientCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$DeviceCanvasClientDescriptorCopyWithImpl<$Res>
    implements $DeviceCanvasClientDescriptorCopyWith<$Res> {
  _$DeviceCanvasClientDescriptorCopyWithImpl(this._self, this._then);

  final DeviceCanvasClientDescriptor _self;
  final $Res Function(DeviceCanvasClientDescriptor) _then;

/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? dimensions = freezed,Object? orientation = freezed,Object? capabilities = null,}) {
  return _then(DeviceCanvasClientDescriptor(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientPlatform,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,dimensions: freezed == dimensions ? _self.dimensions : dimensions // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientDimensions?,orientation: freezed == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientOrientation?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientCapabilities,
  ));
}
/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientDimensionsCopyWith<$Res>? get dimensions {
    if (_self.dimensions == null) {
    return null;
  }

  return $DeviceCanvasClientDimensionsCopyWith<$Res>(_self.dimensions!, (value) {
    return _then(_self.copyWith(dimensions: value));
  });
}/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientCapabilitiesCopyWith<$Res> get capabilities {
  
  return $DeviceCanvasClientCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClientDescriptor implements DeviceCanvasClientDescriptor {
  const _DeviceCanvasClientDescriptor({@JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) required this.platform, required this.displayName, required this.runtimeDescription, required this.modelDescription, required this.dimensions, @JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown) required this.orientation, required this.capabilities});
  factory _DeviceCanvasClientDescriptor.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDescriptorFromJson(json);

@override@JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) final  DeviceCanvasClientPlatform platform;
@override final  String displayName;
@override final  String runtimeDescription;
@override final  String modelDescription;
@override final  DeviceCanvasClientDimensions? dimensions;
@override@JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown) final  DeviceCanvasClientOrientation? orientation;
@override final  DeviceCanvasClientCapabilities capabilities;

/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClientDescriptorCopyWith<_DeviceCanvasClientDescriptor> get copyWith => __$DeviceCanvasClientDescriptorCopyWithImpl<_DeviceCanvasClientDescriptor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClientDescriptorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClientDescriptor&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.dimensions, dimensions) || other.dimensions == dimensions)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platform,displayName,runtimeDescription,modelDescription,dimensions,orientation,capabilities);

@override
String toString() {
  return 'DeviceCanvasClientDescriptor(platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, dimensions: $dimensions, orientation: $orientation, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClientDescriptorCopyWith<$Res> implements $DeviceCanvasClientDescriptorCopyWith<$Res> {
  factory _$DeviceCanvasClientDescriptorCopyWith(_DeviceCanvasClientDescriptor value, $Res Function(_DeviceCanvasClientDescriptor) _then) = __$DeviceCanvasClientDescriptorCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) DeviceCanvasClientPlatform platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasClientDimensions? dimensions,@JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown) DeviceCanvasClientOrientation? orientation, DeviceCanvasClientCapabilities capabilities
});


@override $DeviceCanvasClientDimensionsCopyWith<$Res>? get dimensions;@override $DeviceCanvasClientCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class __$DeviceCanvasClientDescriptorCopyWithImpl<$Res>
    implements _$DeviceCanvasClientDescriptorCopyWith<$Res> {
  __$DeviceCanvasClientDescriptorCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClientDescriptor _self;
  final $Res Function(_DeviceCanvasClientDescriptor) _then;

/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? dimensions = freezed,Object? orientation = freezed,Object? capabilities = null,}) {
  return _then(_DeviceCanvasClientDescriptor(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientPlatform,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,dimensions: freezed == dimensions ? _self.dimensions : dimensions // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientDimensions?,orientation: freezed == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientOrientation?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientCapabilities,
  ));
}

/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientDimensionsCopyWith<$Res>? get dimensions {
    if (_self.dimensions == null) {
    return null;
  }

  return $DeviceCanvasClientDimensionsCopyWith<$Res>(_self.dimensions!, (value) {
    return _then(_self.copyWith(dimensions: value));
  });
}/// Create a copy of DeviceCanvasClientDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientCapabilitiesCopyWith<$Res> get capabilities {
  
  return $DeviceCanvasClientCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}


/// @nodoc
mixin _$DeviceCanvasClaimStatus {

 String get projectId; String get sessionId; int get revision; int get claimedAt; String? get displayTitle;
/// Create a copy of DeviceCanvasClaimStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimStatusCopyWith<DeviceCanvasClaimStatus> get copyWith => _$DeviceCanvasClaimStatusCopyWithImpl<DeviceCanvasClaimStatus>(this as DeviceCanvasClaimStatus, _$identity);

  /// Serializes this DeviceCanvasClaimStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimStatus&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,sessionId,revision,claimedAt,displayTitle);

@override
String toString() {
  return 'DeviceCanvasClaimStatus(projectId: $projectId, sessionId: $sessionId, revision: $revision, claimedAt: $claimedAt, displayTitle: $displayTitle)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimStatusCopyWith<$Res>  {
  factory $DeviceCanvasClaimStatusCopyWith(DeviceCanvasClaimStatus value, $Res Function(DeviceCanvasClaimStatus) _then) = _$DeviceCanvasClaimStatusCopyWithImpl;
@useResult
$Res call({
 String projectId, String sessionId, int revision, int claimedAt, String? displayTitle
});




}
/// @nodoc
class _$DeviceCanvasClaimStatusCopyWithImpl<$Res>
    implements $DeviceCanvasClaimStatusCopyWith<$Res> {
  _$DeviceCanvasClaimStatusCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimStatus _self;
  final $Res Function(DeviceCanvasClaimStatus) _then;

/// Create a copy of DeviceCanvasClaimStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? sessionId = null,Object? revision = null,Object? claimedAt = null,Object? displayTitle = freezed,}) {
  return _then(DeviceCanvasClaimStatus(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,claimedAt: null == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int,displayTitle: freezed == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClaimStatus implements DeviceCanvasClaimStatus {
  const _DeviceCanvasClaimStatus({required this.projectId, required this.sessionId, required this.revision, required this.claimedAt, required this.displayTitle});
  factory _DeviceCanvasClaimStatus.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimStatusFromJson(json);

@override final  String projectId;
@override final  String sessionId;
@override final  int revision;
@override final  int claimedAt;
@override final  String? displayTitle;

/// Create a copy of DeviceCanvasClaimStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClaimStatusCopyWith<_DeviceCanvasClaimStatus> get copyWith => __$DeviceCanvasClaimStatusCopyWithImpl<_DeviceCanvasClaimStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClaimStatus&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,sessionId,revision,claimedAt,displayTitle);

@override
String toString() {
  return 'DeviceCanvasClaimStatus(projectId: $projectId, sessionId: $sessionId, revision: $revision, claimedAt: $claimedAt, displayTitle: $displayTitle)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClaimStatusCopyWith<$Res> implements $DeviceCanvasClaimStatusCopyWith<$Res> {
  factory _$DeviceCanvasClaimStatusCopyWith(_DeviceCanvasClaimStatus value, $Res Function(_DeviceCanvasClaimStatus) _then) = __$DeviceCanvasClaimStatusCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String sessionId, int revision, int claimedAt, String? displayTitle
});




}
/// @nodoc
class __$DeviceCanvasClaimStatusCopyWithImpl<$Res>
    implements _$DeviceCanvasClaimStatusCopyWith<$Res> {
  __$DeviceCanvasClaimStatusCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClaimStatus _self;
  final $Res Function(_DeviceCanvasClaimStatus) _then;

/// Create a copy of DeviceCanvasClaimStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? sessionId = null,Object? revision = null,Object? claimedAt = null,Object? displayTitle = freezed,}) {
  return _then(_DeviceCanvasClaimStatus(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,claimedAt: null == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int,displayTitle: freezed == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasDeviceStatus {

 String get deviceKey; DeviceCanvasClientDescriptor? get descriptor; DeviceCanvasClaimStatus? get claim;
/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasDeviceStatusCopyWith<DeviceCanvasDeviceStatus> get copyWith => _$DeviceCanvasDeviceStatusCopyWithImpl<DeviceCanvasDeviceStatus>(this as DeviceCanvasDeviceStatus, _$identity);

  /// Serializes this DeviceCanvasDeviceStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasDeviceStatus&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.descriptor, descriptor) || other.descriptor == descriptor)&&(identical(other.claim, claim) || other.claim == claim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,descriptor,claim);

@override
String toString() {
  return 'DeviceCanvasDeviceStatus(deviceKey: $deviceKey, descriptor: $descriptor, claim: $claim)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasDeviceStatusCopyWith<$Res>  {
  factory $DeviceCanvasDeviceStatusCopyWith(DeviceCanvasDeviceStatus value, $Res Function(DeviceCanvasDeviceStatus) _then) = _$DeviceCanvasDeviceStatusCopyWithImpl;
@useResult
$Res call({
 String deviceKey, DeviceCanvasClientDescriptor? descriptor, DeviceCanvasClaimStatus? claim
});


$DeviceCanvasClientDescriptorCopyWith<$Res>? get descriptor;$DeviceCanvasClaimStatusCopyWith<$Res>? get claim;

}
/// @nodoc
class _$DeviceCanvasDeviceStatusCopyWithImpl<$Res>
    implements $DeviceCanvasDeviceStatusCopyWith<$Res> {
  _$DeviceCanvasDeviceStatusCopyWithImpl(this._self, this._then);

  final DeviceCanvasDeviceStatus _self;
  final $Res Function(DeviceCanvasDeviceStatus) _then;

/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceKey = null,Object? descriptor = freezed,Object? claim = freezed,}) {
  return _then(DeviceCanvasDeviceStatus(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,descriptor: freezed == descriptor ? _self.descriptor : descriptor // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientDescriptor?,claim: freezed == claim ? _self.claim : claim // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClaimStatus?,
  ));
}
/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientDescriptorCopyWith<$Res>? get descriptor {
    if (_self.descriptor == null) {
    return null;
  }

  return $DeviceCanvasClientDescriptorCopyWith<$Res>(_self.descriptor!, (value) {
    return _then(_self.copyWith(descriptor: value));
  });
}/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClaimStatusCopyWith<$Res>? get claim {
    if (_self.claim == null) {
    return null;
  }

  return $DeviceCanvasClaimStatusCopyWith<$Res>(_self.claim!, (value) {
    return _then(_self.copyWith(claim: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasDeviceStatus implements DeviceCanvasDeviceStatus {
  const _DeviceCanvasDeviceStatus({required this.deviceKey, required this.descriptor, required this.claim});
  factory _DeviceCanvasDeviceStatus.fromJson(Map<String, dynamic> json) => _$DeviceCanvasDeviceStatusFromJson(json);

@override final  String deviceKey;
@override final  DeviceCanvasClientDescriptor? descriptor;
@override final  DeviceCanvasClaimStatus? claim;

/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasDeviceStatusCopyWith<_DeviceCanvasDeviceStatus> get copyWith => __$DeviceCanvasDeviceStatusCopyWithImpl<_DeviceCanvasDeviceStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasDeviceStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasDeviceStatus&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.descriptor, descriptor) || other.descriptor == descriptor)&&(identical(other.claim, claim) || other.claim == claim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,descriptor,claim);

@override
String toString() {
  return 'DeviceCanvasDeviceStatus(deviceKey: $deviceKey, descriptor: $descriptor, claim: $claim)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasDeviceStatusCopyWith<$Res> implements $DeviceCanvasDeviceStatusCopyWith<$Res> {
  factory _$DeviceCanvasDeviceStatusCopyWith(_DeviceCanvasDeviceStatus value, $Res Function(_DeviceCanvasDeviceStatus) _then) = __$DeviceCanvasDeviceStatusCopyWithImpl;
@override @useResult
$Res call({
 String deviceKey, DeviceCanvasClientDescriptor? descriptor, DeviceCanvasClaimStatus? claim
});


@override $DeviceCanvasClientDescriptorCopyWith<$Res>? get descriptor;@override $DeviceCanvasClaimStatusCopyWith<$Res>? get claim;

}
/// @nodoc
class __$DeviceCanvasDeviceStatusCopyWithImpl<$Res>
    implements _$DeviceCanvasDeviceStatusCopyWith<$Res> {
  __$DeviceCanvasDeviceStatusCopyWithImpl(this._self, this._then);

  final _DeviceCanvasDeviceStatus _self;
  final $Res Function(_DeviceCanvasDeviceStatus) _then;

/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,Object? descriptor = freezed,Object? claim = freezed,}) {
  return _then(_DeviceCanvasDeviceStatus(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,descriptor: freezed == descriptor ? _self.descriptor : descriptor // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientDescriptor?,claim: freezed == claim ? _self.claim : claim // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClaimStatus?,
  ));
}

/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClientDescriptorCopyWith<$Res>? get descriptor {
    if (_self.descriptor == null) {
    return null;
  }

  return $DeviceCanvasClientDescriptorCopyWith<$Res>(_self.descriptor!, (value) {
    return _then(_self.copyWith(descriptor: value));
  });
}/// Create a copy of DeviceCanvasDeviceStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClaimStatusCopyWith<$Res>? get claim {
    if (_self.claim == null) {
    return null;
  }

  return $DeviceCanvasClaimStatusCopyWith<$Res>(_self.claim!, (value) {
    return _then(_self.copyWith(claim: value));
  });
}
}


/// @nodoc
mixin _$DeviceCanvasSessionStatusResponse {

 String get bridgeId; String get sessionId; bool get sessionAvailable; String? get projectId;@JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown) DeviceCanvasClientConnectionStatus get connection; List<DeviceCanvasDeviceStatus> get devices; bool get inventoryTruncated; bool get supportsReassignment;
/// Create a copy of DeviceCanvasSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasSessionStatusResponseCopyWith<DeviceCanvasSessionStatusResponse> get copyWith => _$DeviceCanvasSessionStatusResponseCopyWithImpl<DeviceCanvasSessionStatusResponse>(this as DeviceCanvasSessionStatusResponse, _$identity);

  /// Serializes this DeviceCanvasSessionStatusResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasSessionStatusResponse&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionAvailable, sessionAvailable) || other.sessionAvailable == sessionAvailable)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.connection, connection) || other.connection == connection)&&const DeepCollectionEquality().equals(other.devices, devices)&&(identical(other.inventoryTruncated, inventoryTruncated) || other.inventoryTruncated == inventoryTruncated)&&(identical(other.supportsReassignment, supportsReassignment) || other.supportsReassignment == supportsReassignment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,sessionId,sessionAvailable,projectId,connection,const DeepCollectionEquality().hash(devices),inventoryTruncated,supportsReassignment);

@override
String toString() {
  return 'DeviceCanvasSessionStatusResponse(bridgeId: $bridgeId, sessionId: $sessionId, sessionAvailable: $sessionAvailable, projectId: $projectId, connection: $connection, devices: $devices, inventoryTruncated: $inventoryTruncated, supportsReassignment: $supportsReassignment)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasSessionStatusResponseCopyWith<$Res>  {
  factory $DeviceCanvasSessionStatusResponseCopyWith(DeviceCanvasSessionStatusResponse value, $Res Function(DeviceCanvasSessionStatusResponse) _then) = _$DeviceCanvasSessionStatusResponseCopyWithImpl;
@useResult
$Res call({
 String bridgeId, String sessionId, bool sessionAvailable, String? projectId,@JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown) DeviceCanvasClientConnectionStatus connection, List<DeviceCanvasDeviceStatus> devices, bool inventoryTruncated, bool supportsReassignment
});




}
/// @nodoc
class _$DeviceCanvasSessionStatusResponseCopyWithImpl<$Res>
    implements $DeviceCanvasSessionStatusResponseCopyWith<$Res> {
  _$DeviceCanvasSessionStatusResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasSessionStatusResponse _self;
  final $Res Function(DeviceCanvasSessionStatusResponse) _then;

/// Create a copy of DeviceCanvasSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bridgeId = null,Object? sessionId = null,Object? sessionAvailable = null,Object? projectId = freezed,Object? connection = null,Object? devices = null,Object? inventoryTruncated = null,Object? supportsReassignment = null,}) {
  return _then(DeviceCanvasSessionStatusResponse(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionAvailable: null == sessionAvailable ? _self.sessionAvailable : sessionAvailable // ignore: cast_nullable_to_non_nullable
as bool,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientConnectionStatus,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as List<DeviceCanvasDeviceStatus>,inventoryTruncated: null == inventoryTruncated ? _self.inventoryTruncated : inventoryTruncated // ignore: cast_nullable_to_non_nullable
as bool,supportsReassignment: null == supportsReassignment ? _self.supportsReassignment : supportsReassignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasSessionStatusResponse implements DeviceCanvasSessionStatusResponse {
  const _DeviceCanvasSessionStatusResponse({required this.bridgeId, required this.sessionId, required this.sessionAvailable, required this.projectId, @JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown) this.connection = DeviceCanvasClientConnectionStatus.unknown,  List<DeviceCanvasDeviceStatus> devices = const <DeviceCanvasDeviceStatus>[], this.inventoryTruncated = false, this.supportsReassignment = false}): _devices = devices;
  factory _DeviceCanvasSessionStatusResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusResponseFromJson(json);

@override final  String bridgeId;
@override final  String sessionId;
@override final  bool sessionAvailable;
@override final  String? projectId;
@override@JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown) final  DeviceCanvasClientConnectionStatus connection;
 final  List<DeviceCanvasDeviceStatus> _devices;
@override@JsonKey() List<DeviceCanvasDeviceStatus> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

@override@JsonKey() final  bool inventoryTruncated;
@override@JsonKey() final  bool supportsReassignment;

/// Create a copy of DeviceCanvasSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasSessionStatusResponseCopyWith<_DeviceCanvasSessionStatusResponse> get copyWith => __$DeviceCanvasSessionStatusResponseCopyWithImpl<_DeviceCanvasSessionStatusResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasSessionStatusResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasSessionStatusResponse&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionAvailable, sessionAvailable) || other.sessionAvailable == sessionAvailable)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.connection, connection) || other.connection == connection)&&const DeepCollectionEquality().equals(other._devices, _devices)&&(identical(other.inventoryTruncated, inventoryTruncated) || other.inventoryTruncated == inventoryTruncated)&&(identical(other.supportsReassignment, supportsReassignment) || other.supportsReassignment == supportsReassignment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,sessionId,sessionAvailable,projectId,connection,const DeepCollectionEquality().hash(_devices),inventoryTruncated,supportsReassignment);

@override
String toString() {
  return 'DeviceCanvasSessionStatusResponse(bridgeId: $bridgeId, sessionId: $sessionId, sessionAvailable: $sessionAvailable, projectId: $projectId, connection: $connection, devices: $devices, inventoryTruncated: $inventoryTruncated, supportsReassignment: $supportsReassignment)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasSessionStatusResponseCopyWith<$Res> implements $DeviceCanvasSessionStatusResponseCopyWith<$Res> {
  factory _$DeviceCanvasSessionStatusResponseCopyWith(_DeviceCanvasSessionStatusResponse value, $Res Function(_DeviceCanvasSessionStatusResponse) _then) = __$DeviceCanvasSessionStatusResponseCopyWithImpl;
@override @useResult
$Res call({
 String bridgeId, String sessionId, bool sessionAvailable, String? projectId,@JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown) DeviceCanvasClientConnectionStatus connection, List<DeviceCanvasDeviceStatus> devices, bool inventoryTruncated, bool supportsReassignment
});




}
/// @nodoc
class __$DeviceCanvasSessionStatusResponseCopyWithImpl<$Res>
    implements _$DeviceCanvasSessionStatusResponseCopyWith<$Res> {
  __$DeviceCanvasSessionStatusResponseCopyWithImpl(this._self, this._then);

  final _DeviceCanvasSessionStatusResponse _self;
  final $Res Function(_DeviceCanvasSessionStatusResponse) _then;

/// Create a copy of DeviceCanvasSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bridgeId = null,Object? sessionId = null,Object? sessionAvailable = null,Object? projectId = freezed,Object? connection = null,Object? devices = null,Object? inventoryTruncated = null,Object? supportsReassignment = null,}) {
  return _then(_DeviceCanvasSessionStatusResponse(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionAvailable: null == sessionAvailable ? _self.sessionAvailable : sessionAvailable // ignore: cast_nullable_to_non_nullable
as bool,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClientConnectionStatus,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<DeviceCanvasDeviceStatus>,inventoryTruncated: null == inventoryTruncated ? _self.inventoryTruncated : inventoryTruncated // ignore: cast_nullable_to_non_nullable
as bool,supportsReassignment: null == supportsReassignment ? _self.supportsReassignment : supportsReassignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasMutationResponse {

@JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) DeviceCanvasMutationOutcome get outcome; DeviceCanvasSessionStatusResponse get status;
/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasMutationResponseCopyWith<DeviceCanvasMutationResponse> get copyWith => _$DeviceCanvasMutationResponseCopyWithImpl<DeviceCanvasMutationResponse>(this as DeviceCanvasMutationResponse, _$identity);

  /// Serializes this DeviceCanvasMutationResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasMutationResponse&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,outcome,status);

@override
String toString() {
  return 'DeviceCanvasMutationResponse(outcome: $outcome, status: $status)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasMutationResponseCopyWith<$Res>  {
  factory $DeviceCanvasMutationResponseCopyWith(DeviceCanvasMutationResponse value, $Res Function(DeviceCanvasMutationResponse) _then) = _$DeviceCanvasMutationResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) DeviceCanvasMutationOutcome outcome, DeviceCanvasSessionStatusResponse status
});


$DeviceCanvasSessionStatusResponseCopyWith<$Res> get status;

}
/// @nodoc
class _$DeviceCanvasMutationResponseCopyWithImpl<$Res>
    implements $DeviceCanvasMutationResponseCopyWith<$Res> {
  _$DeviceCanvasMutationResponseCopyWithImpl(this._self, this._then);

  final DeviceCanvasMutationResponse _self;
  final $Res Function(DeviceCanvasMutationResponse) _then;

/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? status = null,}) {
  return _then(DeviceCanvasMutationResponse(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as DeviceCanvasMutationOutcome,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DeviceCanvasSessionStatusResponse,
  ));
}
/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasSessionStatusResponseCopyWith<$Res> get status {
  
  return $DeviceCanvasSessionStatusResponseCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasMutationResponse implements DeviceCanvasMutationResponse {
  const _DeviceCanvasMutationResponse({@JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) required this.outcome, required this.status});
  factory _DeviceCanvasMutationResponse.fromJson(Map<String, dynamic> json) => _$DeviceCanvasMutationResponseFromJson(json);

@override@JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) final  DeviceCanvasMutationOutcome outcome;
@override final  DeviceCanvasSessionStatusResponse status;

/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasMutationResponseCopyWith<_DeviceCanvasMutationResponse> get copyWith => __$DeviceCanvasMutationResponseCopyWithImpl<_DeviceCanvasMutationResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasMutationResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasMutationResponse&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,outcome,status);

@override
String toString() {
  return 'DeviceCanvasMutationResponse(outcome: $outcome, status: $status)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasMutationResponseCopyWith<$Res> implements $DeviceCanvasMutationResponseCopyWith<$Res> {
  factory _$DeviceCanvasMutationResponseCopyWith(_DeviceCanvasMutationResponse value, $Res Function(_DeviceCanvasMutationResponse) _then) = __$DeviceCanvasMutationResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) DeviceCanvasMutationOutcome outcome, DeviceCanvasSessionStatusResponse status
});


@override $DeviceCanvasSessionStatusResponseCopyWith<$Res> get status;

}
/// @nodoc
class __$DeviceCanvasMutationResponseCopyWithImpl<$Res>
    implements _$DeviceCanvasMutationResponseCopyWith<$Res> {
  __$DeviceCanvasMutationResponseCopyWithImpl(this._self, this._then);

  final _DeviceCanvasMutationResponse _self;
  final $Res Function(_DeviceCanvasMutationResponse) _then;

/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? status = null,}) {
  return _then(_DeviceCanvasMutationResponse(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as DeviceCanvasMutationOutcome,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DeviceCanvasSessionStatusResponse,
  ));
}

/// Create a copy of DeviceCanvasMutationResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasSessionStatusResponseCopyWith<$Res> get status {
  
  return $DeviceCanvasSessionStatusResponseCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

// dart format on
