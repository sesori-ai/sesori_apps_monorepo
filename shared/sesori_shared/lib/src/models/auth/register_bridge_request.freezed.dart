// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'register_bridge_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterBridgeRequest {

 String get name; String get platform;@JsonKey(includeIfNull: false) String? get bridgeId;
/// Create a copy of RegisterBridgeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterBridgeRequestCopyWith<RegisterBridgeRequest> get copyWith => _$RegisterBridgeRequestCopyWithImpl<RegisterBridgeRequest>(this as RegisterBridgeRequest, _$identity);

  /// Serializes this RegisterBridgeRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterBridgeRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,platform,bridgeId);

@override
String toString() {
  return 'RegisterBridgeRequest(name: $name, platform: $platform, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class $RegisterBridgeRequestCopyWith<$Res>  {
  factory $RegisterBridgeRequestCopyWith(RegisterBridgeRequest value, $Res Function(RegisterBridgeRequest) _then) = _$RegisterBridgeRequestCopyWithImpl;
@useResult
$Res call({
 String name, String platform,@JsonKey(includeIfNull: false) String? bridgeId
});




}
/// @nodoc
class _$RegisterBridgeRequestCopyWithImpl<$Res>
    implements $RegisterBridgeRequestCopyWith<$Res> {
  _$RegisterBridgeRequestCopyWithImpl(this._self, this._then);

  final RegisterBridgeRequest _self;
  final $Res Function(RegisterBridgeRequest) _then;

/// Create a copy of RegisterBridgeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? platform = null,Object? bridgeId = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _RegisterBridgeRequest implements RegisterBridgeRequest {
  const _RegisterBridgeRequest({required this.name, required this.platform, @JsonKey(includeIfNull: false) required this.bridgeId});
  factory _RegisterBridgeRequest.fromJson(Map<String, dynamic> json) => _$RegisterBridgeRequestFromJson(json);

@override final  String name;
@override final  String platform;
@override@JsonKey(includeIfNull: false) final  String? bridgeId;

/// Create a copy of RegisterBridgeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterBridgeRequestCopyWith<_RegisterBridgeRequest> get copyWith => __$RegisterBridgeRequestCopyWithImpl<_RegisterBridgeRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterBridgeRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterBridgeRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,platform,bridgeId);

@override
String toString() {
  return 'RegisterBridgeRequest(name: $name, platform: $platform, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class _$RegisterBridgeRequestCopyWith<$Res> implements $RegisterBridgeRequestCopyWith<$Res> {
  factory _$RegisterBridgeRequestCopyWith(_RegisterBridgeRequest value, $Res Function(_RegisterBridgeRequest) _then) = __$RegisterBridgeRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String platform,@JsonKey(includeIfNull: false) String? bridgeId
});




}
/// @nodoc
class __$RegisterBridgeRequestCopyWithImpl<$Res>
    implements _$RegisterBridgeRequestCopyWith<$Res> {
  __$RegisterBridgeRequestCopyWithImpl(this._self, this._then);

  final _RegisterBridgeRequest _self;
  final $Res Function(_RegisterBridgeRequest) _then;

/// Create a copy of RegisterBridgeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? platform = null,Object? bridgeId = freezed,}) {
  return _then(_RegisterBridgeRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
