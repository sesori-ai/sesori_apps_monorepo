// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'protocol.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceCanvasDimensions {

 int get width; int get height;
/// Create a copy of DeviceCanvasDimensions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasDimensionsCopyWith<DeviceCanvasDimensions> get copyWith => _$DeviceCanvasDimensionsCopyWithImpl<DeviceCanvasDimensions>(this as DeviceCanvasDimensions, _$identity);

  /// Serializes this DeviceCanvasDimensions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasDimensions&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'DeviceCanvasDimensions(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasDimensionsCopyWith<$Res>  {
  factory $DeviceCanvasDimensionsCopyWith(DeviceCanvasDimensions value, $Res Function(DeviceCanvasDimensions) _then) = _$DeviceCanvasDimensionsCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$DeviceCanvasDimensionsCopyWithImpl<$Res>
    implements $DeviceCanvasDimensionsCopyWith<$Res> {
  _$DeviceCanvasDimensionsCopyWithImpl(this._self, this._then);

  final DeviceCanvasDimensions _self;
  final $Res Function(DeviceCanvasDimensions) _then;

/// Create a copy of DeviceCanvasDimensions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,}) {
  return _then(DeviceCanvasDimensions(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasDimensions extends DeviceCanvasDimensions {
  const _DeviceCanvasDimensions({required this.width, required this.height}): super._();
  factory _DeviceCanvasDimensions.fromJson(Map<String, dynamic> json) => _$DeviceCanvasDimensionsFromJson(json);

@override final  int width;
@override final  int height;

/// Create a copy of DeviceCanvasDimensions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasDimensionsCopyWith<_DeviceCanvasDimensions> get copyWith => __$DeviceCanvasDimensionsCopyWithImpl<_DeviceCanvasDimensions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasDimensionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasDimensions&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'DeviceCanvasDimensions(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasDimensionsCopyWith<$Res> implements $DeviceCanvasDimensionsCopyWith<$Res> {
  factory _$DeviceCanvasDimensionsCopyWith(_DeviceCanvasDimensions value, $Res Function(_DeviceCanvasDimensions) _then) = __$DeviceCanvasDimensionsCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class __$DeviceCanvasDimensionsCopyWithImpl<$Res>
    implements _$DeviceCanvasDimensionsCopyWith<$Res> {
  __$DeviceCanvasDimensionsCopyWithImpl(this._self, this._then);

  final _DeviceCanvasDimensions _self;
  final $Res Function(_DeviceCanvasDimensions) _then;

/// Create a copy of DeviceCanvasDimensions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(_DeviceCanvasDimensions(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasCapabilities {

 bool get localView; bool get remoteVideo; bool get remoteControl; bool get input;
/// Create a copy of DeviceCanvasCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasCapabilitiesCopyWith<DeviceCanvasCapabilities> get copyWith => _$DeviceCanvasCapabilitiesCopyWithImpl<DeviceCanvasCapabilities>(this as DeviceCanvasCapabilities, _$identity);

  /// Serializes this DeviceCanvasCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasCapabilities&&(identical(other.localView, localView) || other.localView == localView)&&(identical(other.remoteVideo, remoteVideo) || other.remoteVideo == remoteVideo)&&(identical(other.remoteControl, remoteControl) || other.remoteControl == remoteControl)&&(identical(other.input, input) || other.input == input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localView,remoteVideo,remoteControl,input);

@override
String toString() {
  return 'DeviceCanvasCapabilities(localView: $localView, remoteVideo: $remoteVideo, remoteControl: $remoteControl, input: $input)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasCapabilitiesCopyWith<$Res>  {
  factory $DeviceCanvasCapabilitiesCopyWith(DeviceCanvasCapabilities value, $Res Function(DeviceCanvasCapabilities) _then) = _$DeviceCanvasCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool localView, bool remoteVideo, bool remoteControl, bool input
});




}
/// @nodoc
class _$DeviceCanvasCapabilitiesCopyWithImpl<$Res>
    implements $DeviceCanvasCapabilitiesCopyWith<$Res> {
  _$DeviceCanvasCapabilitiesCopyWithImpl(this._self, this._then);

  final DeviceCanvasCapabilities _self;
  final $Res Function(DeviceCanvasCapabilities) _then;

/// Create a copy of DeviceCanvasCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? localView = null,Object? remoteVideo = null,Object? remoteControl = null,Object? input = null,}) {
  return _then(DeviceCanvasCapabilities(
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

class _DeviceCanvasCapabilities extends DeviceCanvasCapabilities {
  const _DeviceCanvasCapabilities({required this.localView, required this.remoteVideo, required this.remoteControl, required this.input}): super._();
  factory _DeviceCanvasCapabilities.fromJson(Map<String, dynamic> json) => _$DeviceCanvasCapabilitiesFromJson(json);

@override final  bool localView;
@override final  bool remoteVideo;
@override final  bool remoteControl;
@override final  bool input;

/// Create a copy of DeviceCanvasCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasCapabilitiesCopyWith<_DeviceCanvasCapabilities> get copyWith => __$DeviceCanvasCapabilitiesCopyWithImpl<_DeviceCanvasCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasCapabilities&&(identical(other.localView, localView) || other.localView == localView)&&(identical(other.remoteVideo, remoteVideo) || other.remoteVideo == remoteVideo)&&(identical(other.remoteControl, remoteControl) || other.remoteControl == remoteControl)&&(identical(other.input, input) || other.input == input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localView,remoteVideo,remoteControl,input);

@override
String toString() {
  return 'DeviceCanvasCapabilities(localView: $localView, remoteVideo: $remoteVideo, remoteControl: $remoteControl, input: $input)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasCapabilitiesCopyWith<$Res> implements $DeviceCanvasCapabilitiesCopyWith<$Res> {
  factory _$DeviceCanvasCapabilitiesCopyWith(_DeviceCanvasCapabilities value, $Res Function(_DeviceCanvasCapabilities) _then) = __$DeviceCanvasCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool localView, bool remoteVideo, bool remoteControl, bool input
});




}
/// @nodoc
class __$DeviceCanvasCapabilitiesCopyWithImpl<$Res>
    implements _$DeviceCanvasCapabilitiesCopyWith<$Res> {
  __$DeviceCanvasCapabilitiesCopyWithImpl(this._self, this._then);

  final _DeviceCanvasCapabilities _self;
  final $Res Function(_DeviceCanvasCapabilities) _then;

/// Create a copy of DeviceCanvasCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? localView = null,Object? remoteVideo = null,Object? remoteControl = null,Object? input = null,}) {
  return _then(_DeviceCanvasCapabilities(
localView: null == localView ? _self.localView : localView // ignore: cast_nullable_to_non_nullable
as bool,remoteVideo: null == remoteVideo ? _self.remoteVideo : remoteVideo // ignore: cast_nullable_to_non_nullable
as bool,remoteControl: null == remoteControl ? _self.remoteControl : remoteControl // ignore: cast_nullable_to_non_nullable
as bool,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasDescriptor {

 String get deviceKey; DeviceCanvasPlatform get platform; String get displayName; String get runtimeDescription; String get modelDescription; DeviceCanvasDimensions? get dimensions; DeviceCanvasOrientation? get orientation; DeviceCanvasCapabilities get capabilities;
/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasDescriptorCopyWith<DeviceCanvasDescriptor> get copyWith => _$DeviceCanvasDescriptorCopyWithImpl<DeviceCanvasDescriptor>(this as DeviceCanvasDescriptor, _$identity);

  /// Serializes this DeviceCanvasDescriptor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasDescriptor&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.dimensions, dimensions) || other.dimensions == dimensions)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,platform,displayName,runtimeDescription,modelDescription,dimensions,orientation,capabilities);

@override
String toString() {
  return 'DeviceCanvasDescriptor(deviceKey: $deviceKey, platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, dimensions: $dimensions, orientation: $orientation, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasDescriptorCopyWith<$Res>  {
  factory $DeviceCanvasDescriptorCopyWith(DeviceCanvasDescriptor value, $Res Function(DeviceCanvasDescriptor) _then) = _$DeviceCanvasDescriptorCopyWithImpl;
@useResult
$Res call({
 String deviceKey, DeviceCanvasPlatform platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasDimensions? dimensions, DeviceCanvasOrientation? orientation, DeviceCanvasCapabilities capabilities
});


$DeviceCanvasDimensionsCopyWith<$Res>? get dimensions;$DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$DeviceCanvasDescriptorCopyWithImpl<$Res>
    implements $DeviceCanvasDescriptorCopyWith<$Res> {
  _$DeviceCanvasDescriptorCopyWithImpl(this._self, this._then);

  final DeviceCanvasDescriptor _self;
  final $Res Function(DeviceCanvasDescriptor) _then;

/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceKey = null,Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? dimensions = freezed,Object? orientation = freezed,Object? capabilities = null,}) {
  return _then(DeviceCanvasDescriptor(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceCanvasPlatform,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,dimensions: freezed == dimensions ? _self.dimensions : dimensions // ignore: cast_nullable_to_non_nullable
as DeviceCanvasDimensions?,orientation: freezed == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as DeviceCanvasOrientation?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as DeviceCanvasCapabilities,
  ));
}
/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasDimensionsCopyWith<$Res>? get dimensions {
    if (_self.dimensions == null) {
    return null;
  }

  return $DeviceCanvasDimensionsCopyWith<$Res>(_self.dimensions!, (value) {
    return _then(_self.copyWith(dimensions: value));
  });
}/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities {
  
  return $DeviceCanvasCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasDescriptor extends DeviceCanvasDescriptor {
  const _DeviceCanvasDescriptor({required this.deviceKey, required this.platform, required this.displayName, required this.runtimeDescription, required this.modelDescription, required this.dimensions, required this.orientation, required this.capabilities}): super._();
  factory _DeviceCanvasDescriptor.fromJson(Map<String, dynamic> json) => _$DeviceCanvasDescriptorFromJson(json);

@override final  String deviceKey;
@override final  DeviceCanvasPlatform platform;
@override final  String displayName;
@override final  String runtimeDescription;
@override final  String modelDescription;
@override final  DeviceCanvasDimensions? dimensions;
@override final  DeviceCanvasOrientation? orientation;
@override final  DeviceCanvasCapabilities capabilities;

/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasDescriptorCopyWith<_DeviceCanvasDescriptor> get copyWith => __$DeviceCanvasDescriptorCopyWithImpl<_DeviceCanvasDescriptor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasDescriptorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasDescriptor&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.runtimeDescription, runtimeDescription) || other.runtimeDescription == runtimeDescription)&&(identical(other.modelDescription, modelDescription) || other.modelDescription == modelDescription)&&(identical(other.dimensions, dimensions) || other.dimensions == dimensions)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceKey,platform,displayName,runtimeDescription,modelDescription,dimensions,orientation,capabilities);

@override
String toString() {
  return 'DeviceCanvasDescriptor(deviceKey: $deviceKey, platform: $platform, displayName: $displayName, runtimeDescription: $runtimeDescription, modelDescription: $modelDescription, dimensions: $dimensions, orientation: $orientation, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasDescriptorCopyWith<$Res> implements $DeviceCanvasDescriptorCopyWith<$Res> {
  factory _$DeviceCanvasDescriptorCopyWith(_DeviceCanvasDescriptor value, $Res Function(_DeviceCanvasDescriptor) _then) = __$DeviceCanvasDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String deviceKey, DeviceCanvasPlatform platform, String displayName, String runtimeDescription, String modelDescription, DeviceCanvasDimensions? dimensions, DeviceCanvasOrientation? orientation, DeviceCanvasCapabilities capabilities
});


@override $DeviceCanvasDimensionsCopyWith<$Res>? get dimensions;@override $DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class __$DeviceCanvasDescriptorCopyWithImpl<$Res>
    implements _$DeviceCanvasDescriptorCopyWith<$Res> {
  __$DeviceCanvasDescriptorCopyWithImpl(this._self, this._then);

  final _DeviceCanvasDescriptor _self;
  final $Res Function(_DeviceCanvasDescriptor) _then;

/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceKey = null,Object? platform = null,Object? displayName = null,Object? runtimeDescription = null,Object? modelDescription = null,Object? dimensions = freezed,Object? orientation = freezed,Object? capabilities = null,}) {
  return _then(_DeviceCanvasDescriptor(
deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceCanvasPlatform,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,runtimeDescription: null == runtimeDescription ? _self.runtimeDescription : runtimeDescription // ignore: cast_nullable_to_non_nullable
as String,modelDescription: null == modelDescription ? _self.modelDescription : modelDescription // ignore: cast_nullable_to_non_nullable
as String,dimensions: freezed == dimensions ? _self.dimensions : dimensions // ignore: cast_nullable_to_non_nullable
as DeviceCanvasDimensions?,orientation: freezed == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as DeviceCanvasOrientation?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as DeviceCanvasCapabilities,
  ));
}

/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasDimensionsCopyWith<$Res>? get dimensions {
    if (_self.dimensions == null) {
    return null;
  }

  return $DeviceCanvasDimensionsCopyWith<$Res>(_self.dimensions!, (value) {
    return _then(_self.copyWith(dimensions: value));
  });
}/// Create a copy of DeviceCanvasDescriptor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities {
  
  return $DeviceCanvasCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

DeviceCanvasInboundMessage _$DeviceCanvasInboundMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'hello':
          return DeviceCanvasHello.fromJson(
            json
          );
                case 'inventorySnapshot':
          return DeviceCanvasInventorySnapshot.fromJson(
            json
          );
                case 'heartbeat':
          return DeviceCanvasHeartbeat.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'DeviceCanvasInboundMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$DeviceCanvasInboundMessage {



  /// Serializes this DeviceCanvasInboundMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasInboundMessage);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasInboundMessage()';
}


}

/// @nodoc
class $DeviceCanvasInboundMessageCopyWith<$Res>  {
$DeviceCanvasInboundMessageCopyWith(DeviceCanvasInboundMessage _, $Res Function(DeviceCanvasInboundMessage) __);
}



/// @nodoc
@JsonSerializable()

class DeviceCanvasHello implements DeviceCanvasInboundMessage {
  const DeviceCanvasHello({required this.protocolVersion, required this.canvasInstanceId, required this.capabilities,  String? $type}): $type = $type ?? 'hello';
  factory DeviceCanvasHello.fromJson(Map<String, dynamic> json) => _$DeviceCanvasHelloFromJson(json);

 final  int protocolVersion;
 final  String canvasInstanceId;
 final  DeviceCanvasCapabilities capabilities;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasHelloCopyWith<DeviceCanvasHello> get copyWith => _$DeviceCanvasHelloCopyWithImpl<DeviceCanvasHello>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasHelloToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasHello&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.canvasInstanceId, canvasInstanceId) || other.canvasInstanceId == canvasInstanceId)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,canvasInstanceId,capabilities);

@override
String toString() {
  return 'DeviceCanvasInboundMessage.hello(protocolVersion: $protocolVersion, canvasInstanceId: $canvasInstanceId, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasHelloCopyWith<$Res> implements $DeviceCanvasInboundMessageCopyWith<$Res> {
  factory $DeviceCanvasHelloCopyWith(DeviceCanvasHello value, $Res Function(DeviceCanvasHello) _then) = _$DeviceCanvasHelloCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String canvasInstanceId, DeviceCanvasCapabilities capabilities
});


$DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$DeviceCanvasHelloCopyWithImpl<$Res>
    implements $DeviceCanvasHelloCopyWith<$Res> {
  _$DeviceCanvasHelloCopyWithImpl(this._self, this._then);

  final DeviceCanvasHello _self;
  final $Res Function(DeviceCanvasHello) _then;

/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? canvasInstanceId = null,Object? capabilities = null,}) {
  return _then(DeviceCanvasHello(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,canvasInstanceId: null == canvasInstanceId ? _self.canvasInstanceId : canvasInstanceId // ignore: cast_nullable_to_non_nullable
as String,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as DeviceCanvasCapabilities,
  ));
}

/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasCapabilitiesCopyWith<$Res> get capabilities {
  
  return $DeviceCanvasCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class DeviceCanvasInventorySnapshot implements DeviceCanvasInboundMessage {
  const DeviceCanvasInventorySnapshot({required  List<DeviceCanvasDescriptor> devices,  String? $type}): _devices = devices,$type = $type ?? 'inventorySnapshot';
  factory DeviceCanvasInventorySnapshot.fromJson(Map<String, dynamic> json) => _$DeviceCanvasInventorySnapshotFromJson(json);

 final  List<DeviceCanvasDescriptor> _devices;
 List<DeviceCanvasDescriptor> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasInventorySnapshotCopyWith<DeviceCanvasInventorySnapshot> get copyWith => _$DeviceCanvasInventorySnapshotCopyWithImpl<DeviceCanvasInventorySnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasInventorySnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasInventorySnapshot&&const DeepCollectionEquality().equals(other._devices, _devices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_devices));

@override
String toString() {
  return 'DeviceCanvasInboundMessage.inventorySnapshot(devices: $devices)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasInventorySnapshotCopyWith<$Res> implements $DeviceCanvasInboundMessageCopyWith<$Res> {
  factory $DeviceCanvasInventorySnapshotCopyWith(DeviceCanvasInventorySnapshot value, $Res Function(DeviceCanvasInventorySnapshot) _then) = _$DeviceCanvasInventorySnapshotCopyWithImpl;
@useResult
$Res call({
 List<DeviceCanvasDescriptor> devices
});




}
/// @nodoc
class _$DeviceCanvasInventorySnapshotCopyWithImpl<$Res>
    implements $DeviceCanvasInventorySnapshotCopyWith<$Res> {
  _$DeviceCanvasInventorySnapshotCopyWithImpl(this._self, this._then);

  final DeviceCanvasInventorySnapshot _self;
  final $Res Function(DeviceCanvasInventorySnapshot) _then;

/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? devices = null,}) {
  return _then(DeviceCanvasInventorySnapshot(
devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<DeviceCanvasDescriptor>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasHeartbeat implements DeviceCanvasInboundMessage {
  const DeviceCanvasHeartbeat({required this.canvasInstanceId, required this.observedAt,  String? $type}): $type = $type ?? 'heartbeat';
  factory DeviceCanvasHeartbeat.fromJson(Map<String, dynamic> json) => _$DeviceCanvasHeartbeatFromJson(json);

 final  String canvasInstanceId;
 final  int observedAt;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasHeartbeatCopyWith<DeviceCanvasHeartbeat> get copyWith => _$DeviceCanvasHeartbeatCopyWithImpl<DeviceCanvasHeartbeat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasHeartbeatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasHeartbeat&&(identical(other.canvasInstanceId, canvasInstanceId) || other.canvasInstanceId == canvasInstanceId)&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,canvasInstanceId,observedAt);

@override
String toString() {
  return 'DeviceCanvasInboundMessage.heartbeat(canvasInstanceId: $canvasInstanceId, observedAt: $observedAt)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasHeartbeatCopyWith<$Res> implements $DeviceCanvasInboundMessageCopyWith<$Res> {
  factory $DeviceCanvasHeartbeatCopyWith(DeviceCanvasHeartbeat value, $Res Function(DeviceCanvasHeartbeat) _then) = _$DeviceCanvasHeartbeatCopyWithImpl;
@useResult
$Res call({
 String canvasInstanceId, int observedAt
});




}
/// @nodoc
class _$DeviceCanvasHeartbeatCopyWithImpl<$Res>
    implements $DeviceCanvasHeartbeatCopyWith<$Res> {
  _$DeviceCanvasHeartbeatCopyWithImpl(this._self, this._then);

  final DeviceCanvasHeartbeat _self;
  final $Res Function(DeviceCanvasHeartbeat) _then;

/// Create a copy of DeviceCanvasInboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? canvasInstanceId = null,Object? observedAt = null,}) {
  return _then(DeviceCanvasHeartbeat(
canvasInstanceId: null == canvasInstanceId ? _self.canvasInstanceId : canvasInstanceId // ignore: cast_nullable_to_non_nullable
as String,observedAt: null == observedAt ? _self.observedAt : observedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceCanvasClaimProjectionDto {

 String get bridgeId; String get sessionId; String get deviceKey; int get revision; String? get displayTitle;
/// Create a copy of DeviceCanvasClaimProjectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimProjectionDtoCopyWith<DeviceCanvasClaimProjectionDto> get copyWith => _$DeviceCanvasClaimProjectionDtoCopyWithImpl<DeviceCanvasClaimProjectionDto>(this as DeviceCanvasClaimProjectionDto, _$identity);

  /// Serializes this DeviceCanvasClaimProjectionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimProjectionDto&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,sessionId,deviceKey,revision,displayTitle);

@override
String toString() {
  return 'DeviceCanvasClaimProjectionDto(bridgeId: $bridgeId, sessionId: $sessionId, deviceKey: $deviceKey, revision: $revision, displayTitle: $displayTitle)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimProjectionDtoCopyWith<$Res>  {
  factory $DeviceCanvasClaimProjectionDtoCopyWith(DeviceCanvasClaimProjectionDto value, $Res Function(DeviceCanvasClaimProjectionDto) _then) = _$DeviceCanvasClaimProjectionDtoCopyWithImpl;
@useResult
$Res call({
 String bridgeId, String sessionId, String deviceKey, int revision, String? displayTitle
});




}
/// @nodoc
class _$DeviceCanvasClaimProjectionDtoCopyWithImpl<$Res>
    implements $DeviceCanvasClaimProjectionDtoCopyWith<$Res> {
  _$DeviceCanvasClaimProjectionDtoCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimProjectionDto _self;
  final $Res Function(DeviceCanvasClaimProjectionDto) _then;

/// Create a copy of DeviceCanvasClaimProjectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? revision = null,Object? displayTitle = freezed,}) {
  return _then(DeviceCanvasClaimProjectionDto(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,displayTitle: freezed == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasClaimProjectionDto extends DeviceCanvasClaimProjectionDto {
  const _DeviceCanvasClaimProjectionDto({required this.bridgeId, required this.sessionId, required this.deviceKey, required this.revision, required this.displayTitle}): super._();
  factory _DeviceCanvasClaimProjectionDto.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimProjectionDtoFromJson(json);

@override final  String bridgeId;
@override final  String sessionId;
@override final  String deviceKey;
@override final  int revision;
@override final  String? displayTitle;

/// Create a copy of DeviceCanvasClaimProjectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasClaimProjectionDtoCopyWith<_DeviceCanvasClaimProjectionDto> get copyWith => __$DeviceCanvasClaimProjectionDtoCopyWithImpl<_DeviceCanvasClaimProjectionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimProjectionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasClaimProjectionDto&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,sessionId,deviceKey,revision,displayTitle);

@override
String toString() {
  return 'DeviceCanvasClaimProjectionDto(bridgeId: $bridgeId, sessionId: $sessionId, deviceKey: $deviceKey, revision: $revision, displayTitle: $displayTitle)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasClaimProjectionDtoCopyWith<$Res> implements $DeviceCanvasClaimProjectionDtoCopyWith<$Res> {
  factory _$DeviceCanvasClaimProjectionDtoCopyWith(_DeviceCanvasClaimProjectionDto value, $Res Function(_DeviceCanvasClaimProjectionDto) _then) = __$DeviceCanvasClaimProjectionDtoCopyWithImpl;
@override @useResult
$Res call({
 String bridgeId, String sessionId, String deviceKey, int revision, String? displayTitle
});




}
/// @nodoc
class __$DeviceCanvasClaimProjectionDtoCopyWithImpl<$Res>
    implements _$DeviceCanvasClaimProjectionDtoCopyWith<$Res> {
  __$DeviceCanvasClaimProjectionDtoCopyWithImpl(this._self, this._then);

  final _DeviceCanvasClaimProjectionDto _self;
  final $Res Function(_DeviceCanvasClaimProjectionDto) _then;

/// Create a copy of DeviceCanvasClaimProjectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bridgeId = null,Object? sessionId = null,Object? deviceKey = null,Object? revision = null,Object? displayTitle = freezed,}) {
  return _then(_DeviceCanvasClaimProjectionDto(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,displayTitle: freezed == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

DeviceCanvasOutboundMessage _$DeviceCanvasOutboundMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'helloAccepted':
          return DeviceCanvasHelloAccepted.fromJson(
            json
          );
                case 'claimsSnapshot':
          return DeviceCanvasClaimsSnapshot.fromJson(
            json
          );
                case 'claimUpdated':
          return DeviceCanvasClaimUpdatedMessage.fromJson(
            json
          );
                case 'claimRemoved':
          return DeviceCanvasClaimRemovedMessage.fromJson(
            json
          );
                case 'compatibilityStatus':
          return DeviceCanvasCompatibilityStatus.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'DeviceCanvasOutboundMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$DeviceCanvasOutboundMessage {



  /// Serializes this DeviceCanvasOutboundMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasOutboundMessage);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DeviceCanvasOutboundMessage()';
}


}

/// @nodoc
class $DeviceCanvasOutboundMessageCopyWith<$Res>  {
$DeviceCanvasOutboundMessageCopyWith(DeviceCanvasOutboundMessage _, $Res Function(DeviceCanvasOutboundMessage) __);
}



/// @nodoc
@JsonSerializable()

class DeviceCanvasHelloAccepted implements DeviceCanvasOutboundMessage {
  const DeviceCanvasHelloAccepted({required this.protocolVersion, required this.bridgeId,  String? $type}): $type = $type ?? 'helloAccepted';
  factory DeviceCanvasHelloAccepted.fromJson(Map<String, dynamic> json) => _$DeviceCanvasHelloAcceptedFromJson(json);

 final  int protocolVersion;
 final  String bridgeId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasHelloAcceptedCopyWith<DeviceCanvasHelloAccepted> get copyWith => _$DeviceCanvasHelloAcceptedCopyWithImpl<DeviceCanvasHelloAccepted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasHelloAcceptedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasHelloAccepted&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,bridgeId);

@override
String toString() {
  return 'DeviceCanvasOutboundMessage.helloAccepted(protocolVersion: $protocolVersion, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasHelloAcceptedCopyWith<$Res> implements $DeviceCanvasOutboundMessageCopyWith<$Res> {
  factory $DeviceCanvasHelloAcceptedCopyWith(DeviceCanvasHelloAccepted value, $Res Function(DeviceCanvasHelloAccepted) _then) = _$DeviceCanvasHelloAcceptedCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String bridgeId
});




}
/// @nodoc
class _$DeviceCanvasHelloAcceptedCopyWithImpl<$Res>
    implements $DeviceCanvasHelloAcceptedCopyWith<$Res> {
  _$DeviceCanvasHelloAcceptedCopyWithImpl(this._self, this._then);

  final DeviceCanvasHelloAccepted _self;
  final $Res Function(DeviceCanvasHelloAccepted) _then;

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? bridgeId = null,}) {
  return _then(DeviceCanvasHelloAccepted(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasClaimsSnapshot implements DeviceCanvasOutboundMessage {
  const DeviceCanvasClaimsSnapshot({required  List<DeviceCanvasClaimProjectionDto> claims,  String? $type}): _claims = claims,$type = $type ?? 'claimsSnapshot';
  factory DeviceCanvasClaimsSnapshot.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimsSnapshotFromJson(json);

 final  List<DeviceCanvasClaimProjectionDto> _claims;
 List<DeviceCanvasClaimProjectionDto> get claims {
  if (_claims is EqualUnmodifiableListView) return _claims;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_claims);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimsSnapshotCopyWith<DeviceCanvasClaimsSnapshot> get copyWith => _$DeviceCanvasClaimsSnapshotCopyWithImpl<DeviceCanvasClaimsSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimsSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimsSnapshot&&const DeepCollectionEquality().equals(other._claims, _claims));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_claims));

@override
String toString() {
  return 'DeviceCanvasOutboundMessage.claimsSnapshot(claims: $claims)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimsSnapshotCopyWith<$Res> implements $DeviceCanvasOutboundMessageCopyWith<$Res> {
  factory $DeviceCanvasClaimsSnapshotCopyWith(DeviceCanvasClaimsSnapshot value, $Res Function(DeviceCanvasClaimsSnapshot) _then) = _$DeviceCanvasClaimsSnapshotCopyWithImpl;
@useResult
$Res call({
 List<DeviceCanvasClaimProjectionDto> claims
});




}
/// @nodoc
class _$DeviceCanvasClaimsSnapshotCopyWithImpl<$Res>
    implements $DeviceCanvasClaimsSnapshotCopyWith<$Res> {
  _$DeviceCanvasClaimsSnapshotCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimsSnapshot _self;
  final $Res Function(DeviceCanvasClaimsSnapshot) _then;

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? claims = null,}) {
  return _then(DeviceCanvasClaimsSnapshot(
claims: null == claims ? _self._claims : claims // ignore: cast_nullable_to_non_nullable
as List<DeviceCanvasClaimProjectionDto>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasClaimUpdatedMessage implements DeviceCanvasOutboundMessage {
  const DeviceCanvasClaimUpdatedMessage({required this.claim,  String? $type}): $type = $type ?? 'claimUpdated';
  factory DeviceCanvasClaimUpdatedMessage.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimUpdatedMessageFromJson(json);

 final  DeviceCanvasClaimProjectionDto claim;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimUpdatedMessageCopyWith<DeviceCanvasClaimUpdatedMessage> get copyWith => _$DeviceCanvasClaimUpdatedMessageCopyWithImpl<DeviceCanvasClaimUpdatedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimUpdatedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimUpdatedMessage&&(identical(other.claim, claim) || other.claim == claim));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,claim);

@override
String toString() {
  return 'DeviceCanvasOutboundMessage.claimUpdated(claim: $claim)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimUpdatedMessageCopyWith<$Res> implements $DeviceCanvasOutboundMessageCopyWith<$Res> {
  factory $DeviceCanvasClaimUpdatedMessageCopyWith(DeviceCanvasClaimUpdatedMessage value, $Res Function(DeviceCanvasClaimUpdatedMessage) _then) = _$DeviceCanvasClaimUpdatedMessageCopyWithImpl;
@useResult
$Res call({
 DeviceCanvasClaimProjectionDto claim
});


$DeviceCanvasClaimProjectionDtoCopyWith<$Res> get claim;

}
/// @nodoc
class _$DeviceCanvasClaimUpdatedMessageCopyWithImpl<$Res>
    implements $DeviceCanvasClaimUpdatedMessageCopyWith<$Res> {
  _$DeviceCanvasClaimUpdatedMessageCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimUpdatedMessage _self;
  final $Res Function(DeviceCanvasClaimUpdatedMessage) _then;

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? claim = null,}) {
  return _then(DeviceCanvasClaimUpdatedMessage(
claim: null == claim ? _self.claim : claim // ignore: cast_nullable_to_non_nullable
as DeviceCanvasClaimProjectionDto,
  ));
}

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceCanvasClaimProjectionDtoCopyWith<$Res> get claim {
  
  return $DeviceCanvasClaimProjectionDtoCopyWith<$Res>(_self.claim, (value) {
    return _then(_self.copyWith(claim: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class DeviceCanvasClaimRemovedMessage implements DeviceCanvasOutboundMessage {
  const DeviceCanvasClaimRemovedMessage({required this.bridgeId, required this.deviceKey, required this.revision,  String? $type}): $type = $type ?? 'claimRemoved';
  factory DeviceCanvasClaimRemovedMessage.fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimRemovedMessageFromJson(json);

 final  String bridgeId;
 final  String deviceKey;
 final  int revision;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasClaimRemovedMessageCopyWith<DeviceCanvasClaimRemovedMessage> get copyWith => _$DeviceCanvasClaimRemovedMessageCopyWithImpl<DeviceCanvasClaimRemovedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasClaimRemovedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasClaimRemovedMessage&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.deviceKey, deviceKey) || other.deviceKey == deviceKey)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,deviceKey,revision);

@override
String toString() {
  return 'DeviceCanvasOutboundMessage.claimRemoved(bridgeId: $bridgeId, deviceKey: $deviceKey, revision: $revision)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasClaimRemovedMessageCopyWith<$Res> implements $DeviceCanvasOutboundMessageCopyWith<$Res> {
  factory $DeviceCanvasClaimRemovedMessageCopyWith(DeviceCanvasClaimRemovedMessage value, $Res Function(DeviceCanvasClaimRemovedMessage) _then) = _$DeviceCanvasClaimRemovedMessageCopyWithImpl;
@useResult
$Res call({
 String bridgeId, String deviceKey, int revision
});




}
/// @nodoc
class _$DeviceCanvasClaimRemovedMessageCopyWithImpl<$Res>
    implements $DeviceCanvasClaimRemovedMessageCopyWith<$Res> {
  _$DeviceCanvasClaimRemovedMessageCopyWithImpl(this._self, this._then);

  final DeviceCanvasClaimRemovedMessage _self;
  final $Res Function(DeviceCanvasClaimRemovedMessage) _then;

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bridgeId = null,Object? deviceKey = null,Object? revision = null,}) {
  return _then(DeviceCanvasClaimRemovedMessage(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,deviceKey: null == deviceKey ? _self.deviceKey : deviceKey // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeviceCanvasCompatibilityStatus implements DeviceCanvasOutboundMessage {
  const DeviceCanvasCompatibilityStatus({required this.supported, required this.protocolVersion, required this.reason,  String? $type}): $type = $type ?? 'compatibilityStatus';
  factory DeviceCanvasCompatibilityStatus.fromJson(Map<String, dynamic> json) => _$DeviceCanvasCompatibilityStatusFromJson(json);

 final  bool supported;
 final  int protocolVersion;
 final  String reason;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasCompatibilityStatusCopyWith<DeviceCanvasCompatibilityStatus> get copyWith => _$DeviceCanvasCompatibilityStatusCopyWithImpl<DeviceCanvasCompatibilityStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasCompatibilityStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasCompatibilityStatus&&(identical(other.supported, supported) || other.supported == supported)&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supported,protocolVersion,reason);

@override
String toString() {
  return 'DeviceCanvasOutboundMessage.compatibilityStatus(supported: $supported, protocolVersion: $protocolVersion, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasCompatibilityStatusCopyWith<$Res> implements $DeviceCanvasOutboundMessageCopyWith<$Res> {
  factory $DeviceCanvasCompatibilityStatusCopyWith(DeviceCanvasCompatibilityStatus value, $Res Function(DeviceCanvasCompatibilityStatus) _then) = _$DeviceCanvasCompatibilityStatusCopyWithImpl;
@useResult
$Res call({
 bool supported, int protocolVersion, String reason
});




}
/// @nodoc
class _$DeviceCanvasCompatibilityStatusCopyWithImpl<$Res>
    implements $DeviceCanvasCompatibilityStatusCopyWith<$Res> {
  _$DeviceCanvasCompatibilityStatusCopyWithImpl(this._self, this._then);

  final DeviceCanvasCompatibilityStatus _self;
  final $Res Function(DeviceCanvasCompatibilityStatus) _then;

/// Create a copy of DeviceCanvasOutboundMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? supported = null,Object? protocolVersion = null,Object? reason = null,}) {
  return _then(DeviceCanvasCompatibilityStatus(
supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool,protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
