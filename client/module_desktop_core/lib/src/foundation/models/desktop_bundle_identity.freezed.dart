// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_bundle_identity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DesktopBundleIdentity {

 String get version; int get buildNumber; String get sourceSha; DesktopBundleOs get os; DesktopBundleArchitecture get architecture;
/// Create a copy of DesktopBundleIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopBundleIdentityCopyWith<DesktopBundleIdentity> get copyWith => _$DesktopBundleIdentityCopyWithImpl<DesktopBundleIdentity>(this as DesktopBundleIdentity, _$identity);

  /// Serializes this DesktopBundleIdentity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DesktopBundleIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopBundleIdentity&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.buildNumber, _this.buildNumber) || other.buildNumber == _this.buildNumber)&&(identical(other.sourceSha, _this.sourceSha) || other.sourceSha == _this.sourceSha)&&(identical(other.os, _this.os) || other.os == _this.os)&&(identical(other.architecture, _this.architecture) || other.architecture == _this.architecture));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DesktopBundleIdentity;
  return Object.hash(runtimeType,_this.version,_this.buildNumber,_this.sourceSha,_this.os,_this.architecture);
}

@override
String toString() {
  final _this = this as DesktopBundleIdentity;
  return 'DesktopBundleIdentity(version: ${_this.version}, buildNumber: ${_this.buildNumber}, sourceSha: ${_this.sourceSha}, os: ${_this.os}, architecture: ${_this.architecture})';
}


}

/// @nodoc
abstract mixin class $DesktopBundleIdentityCopyWith<$Res>  {
  factory $DesktopBundleIdentityCopyWith(DesktopBundleIdentity value, $Res Function(DesktopBundleIdentity) _then) = _$DesktopBundleIdentityCopyWithImpl;
@useResult
$Res call({
 String version, int buildNumber, String sourceSha, DesktopBundleOs os, DesktopBundleArchitecture architecture
});




}
/// @nodoc
class _$DesktopBundleIdentityCopyWithImpl<$Res>
    implements $DesktopBundleIdentityCopyWith<$Res> {
  _$DesktopBundleIdentityCopyWithImpl(this._self, this._then);

  final DesktopBundleIdentity _self;
  final $Res Function(DesktopBundleIdentity) _then;

/// Create a copy of DesktopBundleIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? buildNumber = null,Object? sourceSha = null,Object? os = null,Object? architecture = null,}) {
  return _then(DesktopBundleIdentity(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,buildNumber: null == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as int,sourceSha: null == sourceSha ? _self.sourceSha : sourceSha // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as DesktopBundleOs,architecture: null == architecture ? _self.architecture : architecture // ignore: cast_nullable_to_non_nullable
as DesktopBundleArchitecture,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DesktopBundleIdentity extends DesktopBundleIdentity {
  const _DesktopBundleIdentity({required this.version, required this.buildNumber, required this.sourceSha, required this.os, required this.architecture}): super._();
  factory _DesktopBundleIdentity.fromJson(Map<String, dynamic> json) => _$DesktopBundleIdentityFromJson(json);

@override final  String version;
@override final  int buildNumber;
@override final  String sourceSha;
@override final  DesktopBundleOs os;
@override final  DesktopBundleArchitecture architecture;

/// Create a copy of DesktopBundleIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesktopBundleIdentityCopyWith<_DesktopBundleIdentity> get copyWith => __$DesktopBundleIdentityCopyWithImpl<_DesktopBundleIdentity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesktopBundleIdentityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesktopBundleIdentity&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.sourceSha, sourceSha) || other.sourceSha == sourceSha)&&(identical(other.os, os) || other.os == os)&&(identical(other.architecture, architecture) || other.architecture == architecture));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,buildNumber,sourceSha,os,architecture);
}

@override
String toString() {
    return 'DesktopBundleIdentity(version: $version, buildNumber: $buildNumber, sourceSha: $sourceSha, os: $os, architecture: $architecture)';
}


}

/// @nodoc
abstract mixin class _$DesktopBundleIdentityCopyWith<$Res> implements $DesktopBundleIdentityCopyWith<$Res> {
  factory _$DesktopBundleIdentityCopyWith(_DesktopBundleIdentity value, $Res Function(_DesktopBundleIdentity) _then) = __$DesktopBundleIdentityCopyWithImpl;
@override @useResult
$Res call({
 String version, int buildNumber, String sourceSha, DesktopBundleOs os, DesktopBundleArchitecture architecture
});




}
/// @nodoc
class __$DesktopBundleIdentityCopyWithImpl<$Res>
    implements _$DesktopBundleIdentityCopyWith<$Res> {
  __$DesktopBundleIdentityCopyWithImpl(this._self, this._then);

  final _DesktopBundleIdentity _self;
  final $Res Function(_DesktopBundleIdentity) _then;

/// Create a copy of DesktopBundleIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? buildNumber = null,Object? sourceSha = null,Object? os = null,Object? architecture = null,}) {
  return _then(_DesktopBundleIdentity(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,buildNumber: null == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as int,sourceSha: null == sourceSha ? _self.sourceSha : sourceSha // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as DesktopBundleOs,architecture: null == architecture ? _self.architecture : architecture // ignore: cast_nullable_to_non_nullable
as DesktopBundleArchitecture,
  ));
}


}

// dart format on
