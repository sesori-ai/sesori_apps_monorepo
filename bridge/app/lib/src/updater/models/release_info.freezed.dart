// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'release_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReleaseInfo {

/// The version string of the release (e.g., "0.3.0").
 String get version;/// The download URL for the platform-specific asset.
 String get assetUrl;/// The URL to the checksums file for verification.
 String get checksumsUrl;
/// Create a copy of ReleaseInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReleaseInfoCopyWith<ReleaseInfo> get copyWith => _$ReleaseInfoCopyWithImpl<ReleaseInfo>(this as ReleaseInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReleaseInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReleaseInfo&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.assetUrl, _this.assetUrl) || other.assetUrl == _this.assetUrl)&&(identical(other.checksumsUrl, _this.checksumsUrl) || other.checksumsUrl == _this.checksumsUrl));
}


@override
int get hashCode {
  final _this = this as ReleaseInfo;
  return Object.hash(runtimeType,_this.version,_this.assetUrl,_this.checksumsUrl);
}

@override
String toString() {
  final _this = this as ReleaseInfo;
  return 'ReleaseInfo(version: ${_this.version}, assetUrl: ${_this.assetUrl}, checksumsUrl: ${_this.checksumsUrl})';
}


}

/// @nodoc
abstract mixin class $ReleaseInfoCopyWith<$Res>  {
  factory $ReleaseInfoCopyWith(ReleaseInfo value, $Res Function(ReleaseInfo) _then) = _$ReleaseInfoCopyWithImpl;
@useResult
$Res call({
 String version, String assetUrl, String checksumsUrl
});




}
/// @nodoc
class _$ReleaseInfoCopyWithImpl<$Res>
    implements $ReleaseInfoCopyWith<$Res> {
  _$ReleaseInfoCopyWithImpl(this._self, this._then);

  final ReleaseInfo _self;
  final $Res Function(ReleaseInfo) _then;

/// Create a copy of ReleaseInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? assetUrl = null,Object? checksumsUrl = null,}) {
  return _then(ReleaseInfo(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,assetUrl: null == assetUrl ? _self.assetUrl : assetUrl // ignore: cast_nullable_to_non_nullable
as String,checksumsUrl: null == checksumsUrl ? _self.checksumsUrl : checksumsUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc


class _ReleaseInfo implements ReleaseInfo {
  const _ReleaseInfo({required this.version, required this.assetUrl, required this.checksumsUrl});
  

/// The version string of the release (e.g., "0.3.0").
@override final  String version;
/// The download URL for the platform-specific asset.
@override final  String assetUrl;
/// The URL to the checksums file for verification.
@override final  String checksumsUrl;

/// Create a copy of ReleaseInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReleaseInfoCopyWith<_ReleaseInfo> get copyWith => __$ReleaseInfoCopyWithImpl<_ReleaseInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReleaseInfo&&(identical(other.version, version) || other.version == version)&&(identical(other.assetUrl, assetUrl) || other.assetUrl == assetUrl)&&(identical(other.checksumsUrl, checksumsUrl) || other.checksumsUrl == checksumsUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,version,assetUrl,checksumsUrl);
}

@override
String toString() {
    return 'ReleaseInfo(version: $version, assetUrl: $assetUrl, checksumsUrl: $checksumsUrl)';
}


}

/// @nodoc
abstract mixin class _$ReleaseInfoCopyWith<$Res> implements $ReleaseInfoCopyWith<$Res> {
  factory _$ReleaseInfoCopyWith(_ReleaseInfo value, $Res Function(_ReleaseInfo) _then) = __$ReleaseInfoCopyWithImpl;
@override @useResult
$Res call({
 String version, String assetUrl, String checksumsUrl
});




}
/// @nodoc
class __$ReleaseInfoCopyWithImpl<$Res>
    implements _$ReleaseInfoCopyWith<$Res> {
  __$ReleaseInfoCopyWithImpl(this._self, this._then);

  final _ReleaseInfo _self;
  final $Res Function(_ReleaseInfo) _then;

/// Create a copy of ReleaseInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? assetUrl = null,Object? checksumsUrl = null,}) {
  return _then(_ReleaseInfo(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,assetUrl: null == assetUrl ? _self.assetUrl : assetUrl // ignore: cast_nullable_to_non_nullable
as String,checksumsUrl: null == checksumsUrl ? _self.checksumsUrl : checksumsUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
