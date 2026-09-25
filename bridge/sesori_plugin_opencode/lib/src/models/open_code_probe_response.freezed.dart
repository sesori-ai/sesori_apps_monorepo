// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_code_probe_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodeProbeResponse {

 String? get version;
/// Create a copy of OpenCodeProbeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodeProbeResponseCopyWith<OpenCodeProbeResponse> get copyWith => _$OpenCodeProbeResponseCopyWithImpl<OpenCodeProbeResponse>(this as OpenCodeProbeResponse, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OpenCodeProbeResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodeProbeResponse&&(identical(other.version, _this.version) || other.version == _this.version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpenCodeProbeResponse;
  return Object.hash(runtimeType,_this.version);
}

@override
String toString() {
  final _this = this as OpenCodeProbeResponse;
  return 'OpenCodeProbeResponse(version: ${_this.version})';
}


}

/// @nodoc
abstract mixin class $OpenCodeProbeResponseCopyWith<$Res>  {
  factory $OpenCodeProbeResponseCopyWith(OpenCodeProbeResponse value, $Res Function(OpenCodeProbeResponse) _then) = _$OpenCodeProbeResponseCopyWithImpl;
@useResult
$Res call({
 String? version
});




}
/// @nodoc
class _$OpenCodeProbeResponseCopyWithImpl<$Res>
    implements $OpenCodeProbeResponseCopyWith<$Res> {
  _$OpenCodeProbeResponseCopyWithImpl(this._self, this._then);

  final OpenCodeProbeResponse _self;
  final $Res Function(OpenCodeProbeResponse) _then;

/// Create a copy of OpenCodeProbeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = freezed,}) {
  return _then(OpenCodeProbeResponse(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc

@JsonSerializable(checked: true)
class _OpenCodeProbeResponse implements OpenCodeProbeResponse {
  const _OpenCodeProbeResponse({required this.version});
  factory _OpenCodeProbeResponse.fromJson(Map<String, dynamic> json) => _$OpenCodeProbeResponseFromJson(json);

@override final  String? version;

/// Create a copy of OpenCodeProbeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodeProbeResponseCopyWith<_OpenCodeProbeResponse> get copyWith => __$OpenCodeProbeResponseCopyWithImpl<_OpenCodeProbeResponse>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodeProbeResponse&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version);
}

@override
String toString() {
    return 'OpenCodeProbeResponse(version: $version)';
}


}

/// @nodoc
abstract mixin class _$OpenCodeProbeResponseCopyWith<$Res> implements $OpenCodeProbeResponseCopyWith<$Res> {
  factory _$OpenCodeProbeResponseCopyWith(_OpenCodeProbeResponse value, $Res Function(_OpenCodeProbeResponse) _then) = __$OpenCodeProbeResponseCopyWithImpl;
@override @useResult
$Res call({
 String? version
});




}
/// @nodoc
class __$OpenCodeProbeResponseCopyWithImpl<$Res>
    implements _$OpenCodeProbeResponseCopyWith<$Res> {
  __$OpenCodeProbeResponseCopyWithImpl(this._self, this._then);

  final _OpenCodeProbeResponse _self;
  final $Res Function(_OpenCodeProbeResponse) _then;

/// Create a copy of OpenCodeProbeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = freezed,}) {
  return _then(_OpenCodeProbeResponse(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
