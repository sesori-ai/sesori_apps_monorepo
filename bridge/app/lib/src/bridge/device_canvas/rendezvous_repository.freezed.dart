// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rendezvous_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceCanvasRendezvous {

 int get protocolVersion; int get port; String get bearerSecret; String get bridgeId; String get processGeneration;
/// Create a copy of DeviceCanvasRendezvous
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCanvasRendezvousCopyWith<DeviceCanvasRendezvous> get copyWith => _$DeviceCanvasRendezvousCopyWithImpl<DeviceCanvasRendezvous>(this as DeviceCanvasRendezvous, _$identity);

  /// Serializes this DeviceCanvasRendezvous to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceCanvasRendezvous&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.port, port) || other.port == port)&&(identical(other.bearerSecret, bearerSecret) || other.bearerSecret == bearerSecret)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.processGeneration, processGeneration) || other.processGeneration == processGeneration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,port,bearerSecret,bridgeId,processGeneration);

@override
String toString() {
  return 'DeviceCanvasRendezvous(protocolVersion: $protocolVersion, port: $port, bearerSecret: $bearerSecret, bridgeId: $bridgeId, processGeneration: $processGeneration)';
}


}

/// @nodoc
abstract mixin class $DeviceCanvasRendezvousCopyWith<$Res>  {
  factory $DeviceCanvasRendezvousCopyWith(DeviceCanvasRendezvous value, $Res Function(DeviceCanvasRendezvous) _then) = _$DeviceCanvasRendezvousCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, int port, String bearerSecret, String bridgeId, String processGeneration
});




}
/// @nodoc
class _$DeviceCanvasRendezvousCopyWithImpl<$Res>
    implements $DeviceCanvasRendezvousCopyWith<$Res> {
  _$DeviceCanvasRendezvousCopyWithImpl(this._self, this._then);

  final DeviceCanvasRendezvous _self;
  final $Res Function(DeviceCanvasRendezvous) _then;

/// Create a copy of DeviceCanvasRendezvous
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? protocolVersion = null,Object? port = null,Object? bearerSecret = null,Object? bridgeId = null,Object? processGeneration = null,}) {
  return _then(DeviceCanvasRendezvous(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bearerSecret: null == bearerSecret ? _self.bearerSecret : bearerSecret // ignore: cast_nullable_to_non_nullable
as String,bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,processGeneration: null == processGeneration ? _self.processGeneration : processGeneration // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeviceCanvasRendezvous extends DeviceCanvasRendezvous {
  const _DeviceCanvasRendezvous({required this.protocolVersion, required this.port, required this.bearerSecret, required this.bridgeId, required this.processGeneration}): super._();
  factory _DeviceCanvasRendezvous.fromJson(Map<String, dynamic> json) => _$DeviceCanvasRendezvousFromJson(json);

@override final  int protocolVersion;
@override final  int port;
@override final  String bearerSecret;
@override final  String bridgeId;
@override final  String processGeneration;

/// Create a copy of DeviceCanvasRendezvous
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCanvasRendezvousCopyWith<_DeviceCanvasRendezvous> get copyWith => __$DeviceCanvasRendezvousCopyWithImpl<_DeviceCanvasRendezvous>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceCanvasRendezvousToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceCanvasRendezvous&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.port, port) || other.port == port)&&(identical(other.bearerSecret, bearerSecret) || other.bearerSecret == bearerSecret)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.processGeneration, processGeneration) || other.processGeneration == processGeneration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,port,bearerSecret,bridgeId,processGeneration);

@override
String toString() {
  return 'DeviceCanvasRendezvous(protocolVersion: $protocolVersion, port: $port, bearerSecret: $bearerSecret, bridgeId: $bridgeId, processGeneration: $processGeneration)';
}


}

/// @nodoc
abstract mixin class _$DeviceCanvasRendezvousCopyWith<$Res> implements $DeviceCanvasRendezvousCopyWith<$Res> {
  factory _$DeviceCanvasRendezvousCopyWith(_DeviceCanvasRendezvous value, $Res Function(_DeviceCanvasRendezvous) _then) = __$DeviceCanvasRendezvousCopyWithImpl;
@override @useResult
$Res call({
 int protocolVersion, int port, String bearerSecret, String bridgeId, String processGeneration
});




}
/// @nodoc
class __$DeviceCanvasRendezvousCopyWithImpl<$Res>
    implements _$DeviceCanvasRendezvousCopyWith<$Res> {
  __$DeviceCanvasRendezvousCopyWithImpl(this._self, this._then);

  final _DeviceCanvasRendezvous _self;
  final $Res Function(_DeviceCanvasRendezvous) _then;

/// Create a copy of DeviceCanvasRendezvous
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? port = null,Object? bearerSecret = null,Object? bridgeId = null,Object? processGeneration = null,}) {
  return _then(_DeviceCanvasRendezvous(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bearerSecret: null == bearerSecret ? _self.bearerSecret : bearerSecret // ignore: cast_nullable_to_non_nullable
as String,bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,processGeneration: null == processGeneration ? _self.processGeneration : processGeneration // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
