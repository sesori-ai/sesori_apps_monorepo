// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_project_storage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexOpenedProject {

 String get path; String? get name; int get addedAt;
/// Create a copy of CodexOpenedProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexOpenedProjectCopyWith<CodexOpenedProject> get copyWith => _$CodexOpenedProjectCopyWithImpl<CodexOpenedProject>(this as CodexOpenedProject, _$identity);

  /// Serializes this CodexOpenedProject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexOpenedProject&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,addedAt);

@override
String toString() {
  return 'CodexOpenedProject(path: $path, name: $name, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class $CodexOpenedProjectCopyWith<$Res>  {
  factory $CodexOpenedProjectCopyWith(CodexOpenedProject value, $Res Function(CodexOpenedProject) _then) = _$CodexOpenedProjectCopyWithImpl;
@useResult
$Res call({
 String path, String? name, int addedAt
});




}
/// @nodoc
class _$CodexOpenedProjectCopyWithImpl<$Res>
    implements $CodexOpenedProjectCopyWith<$Res> {
  _$CodexOpenedProjectCopyWithImpl(this._self, this._then);

  final CodexOpenedProject _self;
  final $Res Function(CodexOpenedProject) _then;

/// Create a copy of CodexOpenedProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? name = freezed,Object? addedAt = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexOpenedProject implements CodexOpenedProject {
  const _CodexOpenedProject({this.path = "", this.name, this.addedAt = 0});
  factory _CodexOpenedProject.fromJson(Map<String, dynamic> json) => _$CodexOpenedProjectFromJson(json);

@override@JsonKey() final  String path;
@override final  String? name;
@override@JsonKey() final  int addedAt;

/// Create a copy of CodexOpenedProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexOpenedProjectCopyWith<_CodexOpenedProject> get copyWith => __$CodexOpenedProjectCopyWithImpl<_CodexOpenedProject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexOpenedProjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexOpenedProject&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,addedAt);

@override
String toString() {
  return 'CodexOpenedProject(path: $path, name: $name, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$CodexOpenedProjectCopyWith<$Res> implements $CodexOpenedProjectCopyWith<$Res> {
  factory _$CodexOpenedProjectCopyWith(_CodexOpenedProject value, $Res Function(_CodexOpenedProject) _then) = __$CodexOpenedProjectCopyWithImpl;
@override @useResult
$Res call({
 String path, String? name, int addedAt
});




}
/// @nodoc
class __$CodexOpenedProjectCopyWithImpl<$Res>
    implements _$CodexOpenedProjectCopyWith<$Res> {
  __$CodexOpenedProjectCopyWithImpl(this._self, this._then);

  final _CodexOpenedProject _self;
  final $Res Function(_CodexOpenedProject) _then;

/// Create a copy of CodexOpenedProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? name = freezed,Object? addedAt = null,}) {
  return _then(_CodexOpenedProject(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
