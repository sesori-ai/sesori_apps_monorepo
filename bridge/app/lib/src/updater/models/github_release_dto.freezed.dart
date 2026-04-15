// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_release_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GitHubReleaseDto {

@JsonKey(name: 'tag_name') String get tagName;@JsonKey(name: 'published_at') String? get publishedAt; bool get draft; bool get prerelease; List<GitHubAssetDto> get assets;
/// Create a copy of GitHubReleaseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubReleaseDtoCopyWith<GitHubReleaseDto> get copyWith => _$GitHubReleaseDtoCopyWithImpl<GitHubReleaseDto>(this as GitHubReleaseDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubReleaseDto&&(identical(other.tagName, tagName) || other.tagName == tagName)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.prerelease, prerelease) || other.prerelease == prerelease)&&const DeepCollectionEquality().equals(other.assets, assets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tagName,publishedAt,draft,prerelease,const DeepCollectionEquality().hash(assets));

@override
String toString() {
  return 'GitHubReleaseDto(tagName: $tagName, publishedAt: $publishedAt, draft: $draft, prerelease: $prerelease, assets: $assets)';
}


}

/// @nodoc
abstract mixin class $GitHubReleaseDtoCopyWith<$Res>  {
  factory $GitHubReleaseDtoCopyWith(GitHubReleaseDto value, $Res Function(GitHubReleaseDto) _then) = _$GitHubReleaseDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'tag_name') String tagName,@JsonKey(name: 'published_at') String? publishedAt, bool draft, bool prerelease, List<GitHubAssetDto> assets
});




}
/// @nodoc
class _$GitHubReleaseDtoCopyWithImpl<$Res>
    implements $GitHubReleaseDtoCopyWith<$Res> {
  _$GitHubReleaseDtoCopyWithImpl(this._self, this._then);

  final GitHubReleaseDto _self;
  final $Res Function(GitHubReleaseDto) _then;

/// Create a copy of GitHubReleaseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tagName = null,Object? publishedAt = freezed,Object? draft = null,Object? prerelease = null,Object? assets = null,}) {
  return _then(_self.copyWith(
tagName: null == tagName ? _self.tagName : tagName // ignore: cast_nullable_to_non_nullable
as String,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as String?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool,prerelease: null == prerelease ? _self.prerelease : prerelease // ignore: cast_nullable_to_non_nullable
as bool,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as List<GitHubAssetDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GitHubReleaseDto implements GitHubReleaseDto {
  const _GitHubReleaseDto({@JsonKey(name: 'tag_name') required this.tagName, @JsonKey(name: 'published_at') required this.publishedAt, required this.draft, required this.prerelease, required final  List<GitHubAssetDto> assets}): _assets = assets;
  factory _GitHubReleaseDto.fromJson(Map<String, dynamic> json) => _$GitHubReleaseDtoFromJson(json);

@override@JsonKey(name: 'tag_name') final  String tagName;
@override@JsonKey(name: 'published_at') final  String? publishedAt;
@override final  bool draft;
@override final  bool prerelease;
 final  List<GitHubAssetDto> _assets;
@override List<GitHubAssetDto> get assets {
  if (_assets is EqualUnmodifiableListView) return _assets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assets);
}


/// Create a copy of GitHubReleaseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubReleaseDtoCopyWith<_GitHubReleaseDto> get copyWith => __$GitHubReleaseDtoCopyWithImpl<_GitHubReleaseDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubReleaseDto&&(identical(other.tagName, tagName) || other.tagName == tagName)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.prerelease, prerelease) || other.prerelease == prerelease)&&const DeepCollectionEquality().equals(other._assets, _assets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tagName,publishedAt,draft,prerelease,const DeepCollectionEquality().hash(_assets));

@override
String toString() {
  return 'GitHubReleaseDto(tagName: $tagName, publishedAt: $publishedAt, draft: $draft, prerelease: $prerelease, assets: $assets)';
}


}

/// @nodoc
abstract mixin class _$GitHubReleaseDtoCopyWith<$Res> implements $GitHubReleaseDtoCopyWith<$Res> {
  factory _$GitHubReleaseDtoCopyWith(_GitHubReleaseDto value, $Res Function(_GitHubReleaseDto) _then) = __$GitHubReleaseDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'tag_name') String tagName,@JsonKey(name: 'published_at') String? publishedAt, bool draft, bool prerelease, List<GitHubAssetDto> assets
});




}
/// @nodoc
class __$GitHubReleaseDtoCopyWithImpl<$Res>
    implements _$GitHubReleaseDtoCopyWith<$Res> {
  __$GitHubReleaseDtoCopyWithImpl(this._self, this._then);

  final _GitHubReleaseDto _self;
  final $Res Function(_GitHubReleaseDto) _then;

/// Create a copy of GitHubReleaseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tagName = null,Object? publishedAt = freezed,Object? draft = null,Object? prerelease = null,Object? assets = null,}) {
  return _then(_GitHubReleaseDto(
tagName: null == tagName ? _self.tagName : tagName // ignore: cast_nullable_to_non_nullable
as String,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as String?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool,prerelease: null == prerelease ? _self.prerelease : prerelease // ignore: cast_nullable_to_non_nullable
as bool,assets: null == assets ? _self._assets : assets // ignore: cast_nullable_to_non_nullable
as List<GitHubAssetDto>,
  ));
}


}


/// @nodoc
mixin _$GitHubAssetDto {

 String get name;@JsonKey(name: 'browser_download_url') String get browserDownloadUrl;
/// Create a copy of GitHubAssetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubAssetDtoCopyWith<GitHubAssetDto> get copyWith => _$GitHubAssetDtoCopyWithImpl<GitHubAssetDto>(this as GitHubAssetDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubAssetDto&&(identical(other.name, name) || other.name == name)&&(identical(other.browserDownloadUrl, browserDownloadUrl) || other.browserDownloadUrl == browserDownloadUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,browserDownloadUrl);

@override
String toString() {
  return 'GitHubAssetDto(name: $name, browserDownloadUrl: $browserDownloadUrl)';
}


}

/// @nodoc
abstract mixin class $GitHubAssetDtoCopyWith<$Res>  {
  factory $GitHubAssetDtoCopyWith(GitHubAssetDto value, $Res Function(GitHubAssetDto) _then) = _$GitHubAssetDtoCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(name: 'browser_download_url') String browserDownloadUrl
});




}
/// @nodoc
class _$GitHubAssetDtoCopyWithImpl<$Res>
    implements $GitHubAssetDtoCopyWith<$Res> {
  _$GitHubAssetDtoCopyWithImpl(this._self, this._then);

  final GitHubAssetDto _self;
  final $Res Function(GitHubAssetDto) _then;

/// Create a copy of GitHubAssetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? browserDownloadUrl = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,browserDownloadUrl: null == browserDownloadUrl ? _self.browserDownloadUrl : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GitHubAssetDto implements GitHubAssetDto {
  const _GitHubAssetDto({required this.name, @JsonKey(name: 'browser_download_url') required this.browserDownloadUrl});
  factory _GitHubAssetDto.fromJson(Map<String, dynamic> json) => _$GitHubAssetDtoFromJson(json);

@override final  String name;
@override@JsonKey(name: 'browser_download_url') final  String browserDownloadUrl;

/// Create a copy of GitHubAssetDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubAssetDtoCopyWith<_GitHubAssetDto> get copyWith => __$GitHubAssetDtoCopyWithImpl<_GitHubAssetDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubAssetDto&&(identical(other.name, name) || other.name == name)&&(identical(other.browserDownloadUrl, browserDownloadUrl) || other.browserDownloadUrl == browserDownloadUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,browserDownloadUrl);

@override
String toString() {
  return 'GitHubAssetDto(name: $name, browserDownloadUrl: $browserDownloadUrl)';
}


}

/// @nodoc
abstract mixin class _$GitHubAssetDtoCopyWith<$Res> implements $GitHubAssetDtoCopyWith<$Res> {
  factory _$GitHubAssetDtoCopyWith(_GitHubAssetDto value, $Res Function(_GitHubAssetDto) _then) = __$GitHubAssetDtoCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(name: 'browser_download_url') String browserDownloadUrl
});




}
/// @nodoc
class __$GitHubAssetDtoCopyWithImpl<$Res>
    implements _$GitHubAssetDtoCopyWith<$Res> {
  __$GitHubAssetDtoCopyWithImpl(this._self, this._then);

  final _GitHubAssetDto _self;
  final $Res Function(_GitHubAssetDto) _then;

/// Create a copy of GitHubAssetDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? browserDownloadUrl = null,}) {
  return _then(_GitHubAssetDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,browserDownloadUrl: null == browserDownloadUrl ? _self.browserDownloadUrl : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
