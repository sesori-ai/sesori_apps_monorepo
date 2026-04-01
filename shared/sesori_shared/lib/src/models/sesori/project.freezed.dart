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

 String get id; String? get name; ProjectTime? get time;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,time);

@override
String toString() {
  return 'Project(id: $id, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String? name, ProjectTime? time
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
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
  const _Project({required this.id, required this.name, required this.time});
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,time);

@override
String toString() {
  return 'Project(id: $id, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, ProjectTime? time
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
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
  const _ProjectTime({required this.created, required this.updated, required this.initialized});
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

// dart format on
