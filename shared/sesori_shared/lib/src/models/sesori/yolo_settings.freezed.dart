// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'yolo_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$YoloSettingsResponse {

/// The bridge-wide default. A session's `approvalOverride` wins over it.
 bool get enabled;/// Whether the bridge stores a per-session approval override and accepts
/// `PATCH /session/approval-override`.
 bool get supportsSessionOverride;
/// Create a copy of YoloSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YoloSettingsResponseCopyWith<YoloSettingsResponse> get copyWith => _$YoloSettingsResponseCopyWithImpl<YoloSettingsResponse>(this as YoloSettingsResponse, _$identity);

  /// Serializes this YoloSettingsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as YoloSettingsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YoloSettingsResponse&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.supportsSessionOverride, _this.supportsSessionOverride) || other.supportsSessionOverride == _this.supportsSessionOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as YoloSettingsResponse;
  return Object.hash(runtimeType,_this.enabled,_this.supportsSessionOverride);
}

@override
String toString() {
  final _this = this as YoloSettingsResponse;
  return 'YoloSettingsResponse(enabled: ${_this.enabled}, supportsSessionOverride: ${_this.supportsSessionOverride})';
}


}

/// @nodoc
abstract mixin class $YoloSettingsResponseCopyWith<$Res>  {
  factory $YoloSettingsResponseCopyWith(YoloSettingsResponse value, $Res Function(YoloSettingsResponse) _then) = _$YoloSettingsResponseCopyWithImpl;
@useResult
$Res call({
 bool enabled, bool supportsSessionOverride
});




}
/// @nodoc
class _$YoloSettingsResponseCopyWithImpl<$Res>
    implements $YoloSettingsResponseCopyWith<$Res> {
  _$YoloSettingsResponseCopyWithImpl(this._self, this._then);

  final YoloSettingsResponse _self;
  final $Res Function(YoloSettingsResponse) _then;

/// Create a copy of YoloSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? supportsSessionOverride = null,}) {
  return _then(YoloSettingsResponse(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,supportsSessionOverride: null == supportsSessionOverride ? _self.supportsSessionOverride : supportsSessionOverride // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _YoloSettingsResponse implements YoloSettingsResponse {
  const _YoloSettingsResponse({required this.enabled, this.supportsSessionOverride = false});
  factory _YoloSettingsResponse.fromJson(Map<String, dynamic> json) => _$YoloSettingsResponseFromJson(json);

/// The bridge-wide default. A session's `approvalOverride` wins over it.
@override final  bool enabled;
/// Whether the bridge stores a per-session approval override and accepts
/// `PATCH /session/approval-override`.
@override@JsonKey() final  bool supportsSessionOverride;

/// Create a copy of YoloSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YoloSettingsResponseCopyWith<_YoloSettingsResponse> get copyWith => __$YoloSettingsResponseCopyWithImpl<_YoloSettingsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YoloSettingsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _YoloSettingsResponse&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.supportsSessionOverride, supportsSessionOverride) || other.supportsSessionOverride == supportsSessionOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled,supportsSessionOverride);
}

@override
String toString() {
    return 'YoloSettingsResponse(enabled: $enabled, supportsSessionOverride: $supportsSessionOverride)';
}


}

/// @nodoc
abstract mixin class _$YoloSettingsResponseCopyWith<$Res> implements $YoloSettingsResponseCopyWith<$Res> {
  factory _$YoloSettingsResponseCopyWith(_YoloSettingsResponse value, $Res Function(_YoloSettingsResponse) _then) = __$YoloSettingsResponseCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, bool supportsSessionOverride
});




}
/// @nodoc
class __$YoloSettingsResponseCopyWithImpl<$Res>
    implements _$YoloSettingsResponseCopyWith<$Res> {
  __$YoloSettingsResponseCopyWithImpl(this._self, this._then);

  final _YoloSettingsResponse _self;
  final $Res Function(_YoloSettingsResponse) _then;

/// Create a copy of YoloSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? supportsSessionOverride = null,}) {
  return _then(_YoloSettingsResponse(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,supportsSessionOverride: null == supportsSessionOverride ? _self.supportsSessionOverride : supportsSessionOverride // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
