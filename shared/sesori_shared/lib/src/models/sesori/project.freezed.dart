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
mixin _$Projects {

 List<Project> get data;
/// Create a copy of Projects
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectsCopyWith<Projects> get copyWith => _$ProjectsCopyWithImpl<Projects>(this as Projects, _$identity);

  /// Serializes this Projects to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Projects&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'Projects(data: $data)';
}


}

/// @nodoc
abstract mixin class $ProjectsCopyWith<$Res>  {
  factory $ProjectsCopyWith(Projects value, $Res Function(Projects) _then) = _$ProjectsCopyWithImpl;
@useResult
$Res call({
 List<Project> data
});




}
/// @nodoc
class _$ProjectsCopyWithImpl<$Res>
    implements $ProjectsCopyWith<$Res> {
  _$ProjectsCopyWithImpl(this._self, this._then);

  final Projects _self;
  final $Res Function(Projects) _then;

/// Create a copy of Projects
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<Project>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _Projects implements Projects {
  const _Projects({required final  List<Project> data}): _data = data;
  factory _Projects.fromJson(Map<String, dynamic> json) => _$ProjectsFromJson(json);

 final  List<Project> _data;
@override List<Project> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of Projects
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectsCopyWith<_Projects> get copyWith => __$ProjectsCopyWithImpl<_Projects>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Projects&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'Projects(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ProjectsCopyWith<$Res> implements $ProjectsCopyWith<$Res> {
  factory _$ProjectsCopyWith(_Projects value, $Res Function(_Projects) _then) = __$ProjectsCopyWithImpl;
@override @useResult
$Res call({
 List<Project> data
});




}
/// @nodoc
class __$ProjectsCopyWithImpl<$Res>
    implements _$ProjectsCopyWith<$Res> {
  __$ProjectsCopyWithImpl(this._self, this._then);

  final _Projects _self;
  final $Res Function(_Projects) _then;

/// Create a copy of Projects
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_Projects(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<Project>,
  ));
}


}


/// @nodoc
mixin _$Project {

 String get id; String? get name;// Live directory of the project on disk — the directory backend operations
// run in. Distinct from [id]: the id is a stable identifier that survives
// folder moves (for git-backed backends it is the original worktree path,
// pinned at first open). Defaults to "" so payloads from older bridges
// (which don't send a path) still decode; clients fall back to [id] when
// empty.
// COMPATIBILITY 2026-07-10 (v1.5.0): Old bridges may omit path. Require path and remove the client id fallback once those bridges are unsupported.
 String get path;// COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges may omit time. Require it and remove bridge/client fallbacks.
 ProjectTime? get time;// Whether this project has at least one non-archived session with unseen
// activity. Backend-derived from its sessions. Defaults to false so older
// payloads (and the baseline) deserialize as "seen".
// COMPATIBILITY 2026-07-03 (v1.3.0): Old bridges omit unseen-change state. Require the field once those bridges are unsupported.
 bool get hasUnseenChanges;// Whether the project's directory no longer exists on disk at its recorded
// location (the folder was moved or deleted). The bridge stamps this from a
// filesystem check; the client renders such projects as "folder not found"
// instead of driving into a dead path. Defaults to false so older payloads
// deserialize as "present".
// COMPATIBILITY 2026-07-08 (v1.4.0): Old bridges omit directory-missing state. Require the field once those bridges are unsupported.
 bool get directoryMissing;// Whether this project can create dedicated Git worktrees. This is a
// capability rather than a raw Git-state field so clients render the
// behavior the bridge can actually provide.
// COMPATIBILITY 2026-07-17 (v1.5.2): Old bridges omit this capability. Default to the prior visible-toggle behavior; require the field once those bridges are unsupported.
 bool get supportsDedicatedWorktrees;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.time, time) || other.time == time)&&(identical(other.hasUnseenChanges, hasUnseenChanges) || other.hasUnseenChanges == hasUnseenChanges)&&(identical(other.directoryMissing, directoryMissing) || other.directoryMissing == directoryMissing)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,path,time,hasUnseenChanges,directoryMissing,supportsDedicatedWorktrees);

@override
String toString() {
  return 'Project(id: $id, name: $name, path: $path, time: $time, hasUnseenChanges: $hasUnseenChanges, directoryMissing: $directoryMissing, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String path, ProjectTime? time, bool hasUnseenChanges, bool directoryMissing, bool supportsDedicatedWorktrees
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? path = null,Object? time = freezed,Object? hasUnseenChanges = null,Object? directoryMissing = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,hasUnseenChanges: null == hasUnseenChanges ? _self.hasUnseenChanges : hasUnseenChanges // ignore: cast_nullable_to_non_nullable
as bool,directoryMissing: null == directoryMissing ? _self.directoryMissing : directoryMissing // ignore: cast_nullable_to_non_nullable
as bool,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
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
  const _Project({required this.id, required this.name, this.path = "", required this.time, this.hasUnseenChanges = false, this.directoryMissing = false, this.supportsDedicatedWorktrees = true});
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
@override final  String? name;
// Live directory of the project on disk — the directory backend operations
// run in. Distinct from [id]: the id is a stable identifier that survives
// folder moves (for git-backed backends it is the original worktree path,
// pinned at first open). Defaults to "" so payloads from older bridges
// (which don't send a path) still decode; clients fall back to [id] when
// empty.
// COMPATIBILITY 2026-07-10 (v1.5.0): Old bridges may omit path. Require path and remove the client id fallback once those bridges are unsupported.
@override@JsonKey() final  String path;
// COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges may omit time. Require it and remove bridge/client fallbacks.
@override final  ProjectTime? time;
// Whether this project has at least one non-archived session with unseen
// activity. Backend-derived from its sessions. Defaults to false so older
// payloads (and the baseline) deserialize as "seen".
// COMPATIBILITY 2026-07-03 (v1.3.0): Old bridges omit unseen-change state. Require the field once those bridges are unsupported.
@override@JsonKey() final  bool hasUnseenChanges;
// Whether the project's directory no longer exists on disk at its recorded
// location (the folder was moved or deleted). The bridge stamps this from a
// filesystem check; the client renders such projects as "folder not found"
// instead of driving into a dead path. Defaults to false so older payloads
// deserialize as "present".
// COMPATIBILITY 2026-07-08 (v1.4.0): Old bridges omit directory-missing state. Require the field once those bridges are unsupported.
@override@JsonKey() final  bool directoryMissing;
// Whether this project can create dedicated Git worktrees. This is a
// capability rather than a raw Git-state field so clients render the
// behavior the bridge can actually provide.
// COMPATIBILITY 2026-07-17 (v1.5.2): Old bridges omit this capability. Default to the prior visible-toggle behavior; require the field once those bridges are unsupported.
@override@JsonKey() final  bool supportsDedicatedWorktrees;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.time, time) || other.time == time)&&(identical(other.hasUnseenChanges, hasUnseenChanges) || other.hasUnseenChanges == hasUnseenChanges)&&(identical(other.directoryMissing, directoryMissing) || other.directoryMissing == directoryMissing)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,path,time,hasUnseenChanges,directoryMissing,supportsDedicatedWorktrees);

@override
String toString() {
  return 'Project(id: $id, name: $name, path: $path, time: $time, hasUnseenChanges: $hasUnseenChanges, directoryMissing: $directoryMissing, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String path, ProjectTime? time, bool hasUnseenChanges, bool directoryMissing, bool supportsDedicatedWorktrees
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? path = null,Object? time = freezed,Object? hasUnseenChanges = null,Object? directoryMissing = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,hasUnseenChanges: null == hasUnseenChanges ? _self.hasUnseenChanges : hasUnseenChanges // ignore: cast_nullable_to_non_nullable
as bool,directoryMissing: null == directoryMissing ? _self.directoryMissing : directoryMissing // ignore: cast_nullable_to_non_nullable
as bool,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
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

 int get created; int get updated;
/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<ProjectTime> get copyWith => _$ProjectTimeCopyWithImpl<ProjectTime>(this as ProjectTime, _$identity);

  /// Serializes this ProjectTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated);

@override
String toString() {
  return 'ProjectTime(created: $created, updated: $updated)';
}


}

/// @nodoc
abstract mixin class $ProjectTimeCopyWith<$Res>  {
  factory $ProjectTimeCopyWith(ProjectTime value, $Res Function(ProjectTime) _then) = _$ProjectTimeCopyWithImpl;
@useResult
$Res call({
 int created, int updated
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
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProjectTime implements ProjectTime {
  const _ProjectTime({required this.created, required this.updated});
  factory _ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);

@override final  int created;
@override final  int updated;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated);

@override
String toString() {
  return 'ProjectTime(created: $created, updated: $updated)';
}


}

/// @nodoc
abstract mixin class _$ProjectTimeCopyWith<$Res> implements $ProjectTimeCopyWith<$Res> {
  factory _$ProjectTimeCopyWith(_ProjectTime value, $Res Function(_ProjectTime) _then) = __$ProjectTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated
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
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,}) {
  return _then(_ProjectTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ProjectIdRequest {

 String get projectId;
/// Create a copy of ProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectIdRequestCopyWith<ProjectIdRequest> get copyWith => _$ProjectIdRequestCopyWithImpl<ProjectIdRequest>(this as ProjectIdRequest, _$identity);

  /// Serializes this ProjectIdRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectIdRequest&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId);

@override
String toString() {
  return 'ProjectIdRequest(projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class $ProjectIdRequestCopyWith<$Res>  {
  factory $ProjectIdRequestCopyWith(ProjectIdRequest value, $Res Function(ProjectIdRequest) _then) = _$ProjectIdRequestCopyWithImpl;
@useResult
$Res call({
 String projectId
});




}
/// @nodoc
class _$ProjectIdRequestCopyWithImpl<$Res>
    implements $ProjectIdRequestCopyWith<$Res> {
  _$ProjectIdRequestCopyWithImpl(this._self, this._then);

  final ProjectIdRequest _self;
  final $Res Function(ProjectIdRequest) _then;

/// Create a copy of ProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProjectIdRequest implements ProjectIdRequest {
  const _ProjectIdRequest({required this.projectId});
  factory _ProjectIdRequest.fromJson(Map<String, dynamic> json) => _$ProjectIdRequestFromJson(json);

@override final  String projectId;

/// Create a copy of ProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectIdRequestCopyWith<_ProjectIdRequest> get copyWith => __$ProjectIdRequestCopyWithImpl<_ProjectIdRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectIdRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectIdRequest&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId);

@override
String toString() {
  return 'ProjectIdRequest(projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class _$ProjectIdRequestCopyWith<$Res> implements $ProjectIdRequestCopyWith<$Res> {
  factory _$ProjectIdRequestCopyWith(_ProjectIdRequest value, $Res Function(_ProjectIdRequest) _then) = __$ProjectIdRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId
});




}
/// @nodoc
class __$ProjectIdRequestCopyWithImpl<$Res>
    implements _$ProjectIdRequestCopyWith<$Res> {
  __$ProjectIdRequestCopyWithImpl(this._self, this._then);

  final _ProjectIdRequest _self;
  final $Res Function(_ProjectIdRequest) _then;

/// Create a copy of ProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,}) {
  return _then(_ProjectIdRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProjectPathRequest {

 String get path;
/// Create a copy of ProjectPathRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectPathRequestCopyWith<ProjectPathRequest> get copyWith => _$ProjectPathRequestCopyWithImpl<ProjectPathRequest>(this as ProjectPathRequest, _$identity);

  /// Serializes this ProjectPathRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectPathRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'ProjectPathRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class $ProjectPathRequestCopyWith<$Res>  {
  factory $ProjectPathRequestCopyWith(ProjectPathRequest value, $Res Function(ProjectPathRequest) _then) = _$ProjectPathRequestCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$ProjectPathRequestCopyWithImpl<$Res>
    implements $ProjectPathRequestCopyWith<$Res> {
  _$ProjectPathRequestCopyWithImpl(this._self, this._then);

  final ProjectPathRequest _self;
  final $Res Function(ProjectPathRequest) _then;

/// Create a copy of ProjectPathRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProjectPathRequest implements ProjectPathRequest {
  const _ProjectPathRequest({required this.path});
  factory _ProjectPathRequest.fromJson(Map<String, dynamic> json) => _$ProjectPathRequestFromJson(json);

@override final  String path;

/// Create a copy of ProjectPathRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectPathRequestCopyWith<_ProjectPathRequest> get copyWith => __$ProjectPathRequestCopyWithImpl<_ProjectPathRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectPathRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectPathRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'ProjectPathRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class _$ProjectPathRequestCopyWith<$Res> implements $ProjectPathRequestCopyWith<$Res> {
  factory _$ProjectPathRequestCopyWith(_ProjectPathRequest value, $Res Function(_ProjectPathRequest) _then) = __$ProjectPathRequestCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$ProjectPathRequestCopyWithImpl<$Res>
    implements _$ProjectPathRequestCopyWith<$Res> {
  __$ProjectPathRequestCopyWithImpl(this._self, this._then);

  final _ProjectPathRequest _self;
  final $Res Function(_ProjectPathRequest) _then;

/// Create a copy of ProjectPathRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_ProjectPathRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OpenProjectRequest {

 String get path;// COMPATIBILITY 2026-07-17 (v1.5.2): Old apps send only path. Keep opening without Git until those apps are unsupported.
 OpenProjectGitAction get gitAction;
/// Create a copy of OpenProjectRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenProjectRequestCopyWith<OpenProjectRequest> get copyWith => _$OpenProjectRequestCopyWithImpl<OpenProjectRequest>(this as OpenProjectRequest, _$identity);

  /// Serializes this OpenProjectRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenProjectRequest&&(identical(other.path, path) || other.path == path)&&(identical(other.gitAction, gitAction) || other.gitAction == gitAction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,gitAction);

@override
String toString() {
  return 'OpenProjectRequest(path: $path, gitAction: $gitAction)';
}


}

/// @nodoc
abstract mixin class $OpenProjectRequestCopyWith<$Res>  {
  factory $OpenProjectRequestCopyWith(OpenProjectRequest value, $Res Function(OpenProjectRequest) _then) = _$OpenProjectRequestCopyWithImpl;
@useResult
$Res call({
 String path, OpenProjectGitAction gitAction
});




}
/// @nodoc
class _$OpenProjectRequestCopyWithImpl<$Res>
    implements $OpenProjectRequestCopyWith<$Res> {
  _$OpenProjectRequestCopyWithImpl(this._self, this._then);

  final OpenProjectRequest _self;
  final $Res Function(OpenProjectRequest) _then;

/// Create a copy of OpenProjectRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? gitAction = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,gitAction: null == gitAction ? _self.gitAction : gitAction // ignore: cast_nullable_to_non_nullable
as OpenProjectGitAction,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _OpenProjectRequest implements OpenProjectRequest {
  const _OpenProjectRequest({required this.path, this.gitAction = OpenProjectGitAction.openWithoutGit});
  factory _OpenProjectRequest.fromJson(Map<String, dynamic> json) => _$OpenProjectRequestFromJson(json);

@override final  String path;
// COMPATIBILITY 2026-07-17 (v1.5.2): Old apps send only path. Keep opening without Git until those apps are unsupported.
@override@JsonKey() final  OpenProjectGitAction gitAction;

/// Create a copy of OpenProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenProjectRequestCopyWith<_OpenProjectRequest> get copyWith => __$OpenProjectRequestCopyWithImpl<_OpenProjectRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenProjectRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenProjectRequest&&(identical(other.path, path) || other.path == path)&&(identical(other.gitAction, gitAction) || other.gitAction == gitAction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,gitAction);

@override
String toString() {
  return 'OpenProjectRequest(path: $path, gitAction: $gitAction)';
}


}

/// @nodoc
abstract mixin class _$OpenProjectRequestCopyWith<$Res> implements $OpenProjectRequestCopyWith<$Res> {
  factory _$OpenProjectRequestCopyWith(_OpenProjectRequest value, $Res Function(_OpenProjectRequest) _then) = __$OpenProjectRequestCopyWithImpl;
@override @useResult
$Res call({
 String path, OpenProjectGitAction gitAction
});




}
/// @nodoc
class __$OpenProjectRequestCopyWithImpl<$Res>
    implements _$OpenProjectRequestCopyWith<$Res> {
  __$OpenProjectRequestCopyWithImpl(this._self, this._then);

  final _OpenProjectRequest _self;
  final $Res Function(_OpenProjectRequest) _then;

/// Create a copy of OpenProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? gitAction = null,}) {
  return _then(_OpenProjectRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,gitAction: null == gitAction ? _self.gitAction : gitAction // ignore: cast_nullable_to_non_nullable
as OpenProjectGitAction,
  ));
}


}

// dart format on
