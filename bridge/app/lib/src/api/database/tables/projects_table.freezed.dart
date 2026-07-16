// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projects_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectDto {

 String get projectId; String get path; bool get hidden; String? get baseBranch; String? get displayName; int get createdAt; int get updatedAt; int get projectionUpdatedAt;
/// Create a copy of ProjectDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectDtoCopyWith<ProjectDto> get copyWith => _$ProjectDtoCopyWithImpl<ProjectDto>(this as ProjectDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectDto&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.path, path) || other.path == path)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.projectionUpdatedAt, projectionUpdatedAt) || other.projectionUpdatedAt == projectionUpdatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,path,hidden,baseBranch,displayName,createdAt,updatedAt,projectionUpdatedAt);

@override
String toString() {
  return 'ProjectDto(projectId: $projectId, path: $path, hidden: $hidden, baseBranch: $baseBranch, displayName: $displayName, createdAt: $createdAt, updatedAt: $updatedAt, projectionUpdatedAt: $projectionUpdatedAt)';
}


}

/// @nodoc
abstract mixin class $ProjectDtoCopyWith<$Res>  {
  factory $ProjectDtoCopyWith(ProjectDto value, $Res Function(ProjectDto) _then) = _$ProjectDtoCopyWithImpl;
@useResult
$Res call({
 String projectId, String path, bool hidden, String? baseBranch, String? displayName, int createdAt, int updatedAt, int projectionUpdatedAt
});




}
/// @nodoc
class _$ProjectDtoCopyWithImpl<$Res>
    implements $ProjectDtoCopyWith<$Res> {
  _$ProjectDtoCopyWithImpl(this._self, this._then);

  final ProjectDto _self;
  final $Res Function(ProjectDto) _then;

/// Create a copy of ProjectDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? path = null,Object? hidden = null,Object? baseBranch = freezed,Object? displayName = freezed,Object? createdAt = null,Object? updatedAt = null,Object? projectionUpdatedAt = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,projectionUpdatedAt: null == projectionUpdatedAt ? _self.projectionUpdatedAt : projectionUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _ProjectDto extends ProjectDto {
  const _ProjectDto({required this.projectId, required this.path, this.hidden = false, this.baseBranch, this.displayName, required this.createdAt, required this.updatedAt, required this.projectionUpdatedAt}): super._();
  

@override final  String projectId;
@override final  String path;
@override@JsonKey() final  bool hidden;
@override final  String? baseBranch;
@override final  String? displayName;
@override final  int createdAt;
@override final  int updatedAt;
@override final  int projectionUpdatedAt;

/// Create a copy of ProjectDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectDtoCopyWith<_ProjectDto> get copyWith => __$ProjectDtoCopyWithImpl<_ProjectDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectDto&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.path, path) || other.path == path)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.projectionUpdatedAt, projectionUpdatedAt) || other.projectionUpdatedAt == projectionUpdatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,path,hidden,baseBranch,displayName,createdAt,updatedAt,projectionUpdatedAt);

@override
String toString() {
  return 'ProjectDto(projectId: $projectId, path: $path, hidden: $hidden, baseBranch: $baseBranch, displayName: $displayName, createdAt: $createdAt, updatedAt: $updatedAt, projectionUpdatedAt: $projectionUpdatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectDtoCopyWith<$Res> implements $ProjectDtoCopyWith<$Res> {
  factory _$ProjectDtoCopyWith(_ProjectDto value, $Res Function(_ProjectDto) _then) = __$ProjectDtoCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String path, bool hidden, String? baseBranch, String? displayName, int createdAt, int updatedAt, int projectionUpdatedAt
});




}
/// @nodoc
class __$ProjectDtoCopyWithImpl<$Res>
    implements _$ProjectDtoCopyWith<$Res> {
  __$ProjectDtoCopyWithImpl(this._self, this._then);

  final _ProjectDto _self;
  final $Res Function(_ProjectDto) _then;

/// Create a copy of ProjectDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? path = null,Object? hidden = null,Object? baseBranch = freezed,Object? displayName = freezed,Object? createdAt = null,Object? updatedAt = null,Object? projectionUpdatedAt = null,}) {
  return _then(_ProjectDto(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,projectionUpdatedAt: null == projectionUpdatedAt ? _self.projectionUpdatedAt : projectionUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
