// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cached_release.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CachedRelease {

/// The latest version string found during the check.
 String get latestVersion;/// The download URL for the latest release.
 String get downloadUrl;/// The URL to the checksums file for verification.
 String get checksumsUrl;/// When this release was published upstream.
 DateTime get publishedAt;/// When this cache entry was created.
 DateTime get checkedAt;
/// Create a copy of CachedRelease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CachedReleaseCopyWith<CachedRelease> get copyWith => _$CachedReleaseCopyWithImpl<CachedRelease>(this as CachedRelease, _$identity);

  /// Serializes this CachedRelease to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CachedRelease&&(identical(other.latestVersion, latestVersion) || other.latestVersion == latestVersion)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.checksumsUrl, checksumsUrl) || other.checksumsUrl == checksumsUrl)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latestVersion,downloadUrl,checksumsUrl,publishedAt,checkedAt);

@override
String toString() {
  return 'CachedRelease(latestVersion: $latestVersion, downloadUrl: $downloadUrl, checksumsUrl: $checksumsUrl, publishedAt: $publishedAt, checkedAt: $checkedAt)';
}


}

/// @nodoc
abstract mixin class $CachedReleaseCopyWith<$Res>  {
  factory $CachedReleaseCopyWith(CachedRelease value, $Res Function(CachedRelease) _then) = _$CachedReleaseCopyWithImpl;
@useResult
$Res call({
 String latestVersion, String downloadUrl, String checksumsUrl, DateTime publishedAt, DateTime checkedAt
});




}
/// @nodoc
class _$CachedReleaseCopyWithImpl<$Res>
    implements $CachedReleaseCopyWith<$Res> {
  _$CachedReleaseCopyWithImpl(this._self, this._then);

  final CachedRelease _self;
  final $Res Function(CachedRelease) _then;

/// Create a copy of CachedRelease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latestVersion = null,Object? downloadUrl = null,Object? checksumsUrl = null,Object? publishedAt = null,Object? checkedAt = null,}) {
  return _then(_self.copyWith(
latestVersion: null == latestVersion ? _self.latestVersion : latestVersion // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,checksumsUrl: null == checksumsUrl ? _self.checksumsUrl : checksumsUrl // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CachedRelease implements CachedRelease {
  const _CachedRelease({required this.latestVersion, required this.downloadUrl, required this.checksumsUrl, required this.publishedAt, required this.checkedAt});
  factory _CachedRelease.fromJson(Map<String, dynamic> json) => _$CachedReleaseFromJson(json);

/// The latest version string found during the check.
@override final  String latestVersion;
/// The download URL for the latest release.
@override final  String downloadUrl;
/// The URL to the checksums file for verification.
@override final  String checksumsUrl;
/// When this release was published upstream.
@override final  DateTime publishedAt;
/// When this cache entry was created.
@override final  DateTime checkedAt;

/// Create a copy of CachedRelease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CachedReleaseCopyWith<_CachedRelease> get copyWith => __$CachedReleaseCopyWithImpl<_CachedRelease>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CachedReleaseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CachedRelease&&(identical(other.latestVersion, latestVersion) || other.latestVersion == latestVersion)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.checksumsUrl, checksumsUrl) || other.checksumsUrl == checksumsUrl)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latestVersion,downloadUrl,checksumsUrl,publishedAt,checkedAt);

@override
String toString() {
  return 'CachedRelease(latestVersion: $latestVersion, downloadUrl: $downloadUrl, checksumsUrl: $checksumsUrl, publishedAt: $publishedAt, checkedAt: $checkedAt)';
}


}

/// @nodoc
abstract mixin class _$CachedReleaseCopyWith<$Res> implements $CachedReleaseCopyWith<$Res> {
  factory _$CachedReleaseCopyWith(_CachedRelease value, $Res Function(_CachedRelease) _then) = __$CachedReleaseCopyWithImpl;
@override @useResult
$Res call({
 String latestVersion, String downloadUrl, String checksumsUrl, DateTime publishedAt, DateTime checkedAt
});




}
/// @nodoc
class __$CachedReleaseCopyWithImpl<$Res>
    implements _$CachedReleaseCopyWith<$Res> {
  __$CachedReleaseCopyWithImpl(this._self, this._then);

  final _CachedRelease _self;
  final $Res Function(_CachedRelease) _then;

/// Create a copy of CachedRelease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latestVersion = null,Object? downloadUrl = null,Object? checksumsUrl = null,Object? publishedAt = null,Object? checkedAt = null,}) {
  return _then(_CachedRelease(
latestVersion: null == latestVersion ? _self.latestVersion : latestVersion // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,checksumsUrl: null == checksumsUrl ? _self.checksumsUrl : checksumsUrl // ignore: cast_nullable_to_non_nullable
as String,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
