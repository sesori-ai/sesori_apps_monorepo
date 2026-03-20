// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Project {

 String get id; String get worktree; String? get name; ProjectTime? get time;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, id) || other.id == id)&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktree,name,time);

@override
String toString() {
  return 'Project(id: $id, worktree: $worktree, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String worktree, String? name, ProjectTime? time
});


$ProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? worktree = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,
  ));
}
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $ProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _Project implements Project {
  const _Project({required this.id, required this.worktree, this.name, this.time});
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
@override final  String worktree;
@override final  String? name;
@override final  ProjectTime? time;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,worktree,name,time);

@override
String toString() {
  return 'Project(id: $id, worktree: $worktree, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String worktree, String? name, ProjectTime? time
});


@override $ProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? worktree = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,
  ));
}

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $ProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}


/// @nodoc
mixin _$ProjectTime {

 int get created; int get updated; int? get initialized;
/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<ProjectTime> get copyWith => _$ProjectTimeCopyWithImpl<ProjectTime>(this as ProjectTime, _$identity);

  /// Serializes this ProjectTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.initialized, initialized) || other.initialized == initialized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,initialized);

@override
String toString() {
  return 'ProjectTime(created: $created, updated: $updated, initialized: $initialized)';
}


}

/// @nodoc
abstract mixin class $ProjectTimeCopyWith<$Res>  {
  factory $ProjectTimeCopyWith(ProjectTime value, $Res Function(ProjectTime) _then) = _$ProjectTimeCopyWithImpl;
@useResult
$Res call({
 int created, int updated, int? initialized
});




}
/// @nodoc
class _$ProjectTimeCopyWithImpl<$Res>
    implements $ProjectTimeCopyWith<$Res> {
  _$ProjectTimeCopyWithImpl(this._self, this._then);

  final ProjectTime _self;
  final $Res Function(ProjectTime) _then;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? initialized = freezed,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,initialized: freezed == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProjectTime implements ProjectTime {
  const _ProjectTime({required this.created, required this.updated, this.initialized});
  factory _ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);

@override final  int created;
@override final  int updated;
@override final  int? initialized;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectTimeCopyWith<_ProjectTime> get copyWith => __$ProjectTimeCopyWithImpl<_ProjectTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.initialized, initialized) || other.initialized == initialized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,initialized);

@override
String toString() {
  return 'ProjectTime(created: $created, updated: $updated, initialized: $initialized)';
}


}

/// @nodoc
abstract mixin class _$ProjectTimeCopyWith<$Res> implements $ProjectTimeCopyWith<$Res> {
  factory _$ProjectTimeCopyWith(_ProjectTime value, $Res Function(_ProjectTime) _then) = __$ProjectTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated, int? initialized
});




}
/// @nodoc
class __$ProjectTimeCopyWithImpl<$Res>
    implements _$ProjectTimeCopyWith<$Res> {
  __$ProjectTimeCopyWithImpl(this._self, this._then);

  final _ProjectTime _self;
  final $Res Function(_ProjectTime) _then;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? initialized = freezed,}) {
  return _then(_ProjectTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,initialized: freezed == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
