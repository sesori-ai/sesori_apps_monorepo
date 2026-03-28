// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectListState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProjectListState()';
}


}

/// @nodoc
class $ProjectListStateCopyWith<$Res>  {
$ProjectListStateCopyWith(ProjectListState _, $Res Function(ProjectListState) __);
}



/// @nodoc


class ProjectListLoading implements ProjectListState {
  const ProjectListLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProjectListState.loading()';
}


}




/// @nodoc


class ProjectListLoaded implements ProjectListState {
  const ProjectListLoaded({required final  List<Project> projects, required final  Map<String, int> activityById, this.isRefreshing = false}): _projects = projects,_activityById = activityById;
  

 final  List<Project> _projects;
 List<Project> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}

 final  Map<String, int> _activityById;
 Map<String, int> get activityById {
  if (_activityById is EqualUnmodifiableMapView) return _activityById;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_activityById);
}

@JsonKey() final  bool isRefreshing;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListLoadedCopyWith<ProjectListLoaded> get copyWith => _$ProjectListLoadedCopyWithImpl<ProjectListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListLoaded&&const DeepCollectionEquality().equals(other._projects, _projects)&&const DeepCollectionEquality().equals(other._activityById, _activityById)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_projects),const DeepCollectionEquality().hash(_activityById),isRefreshing);

@override
String toString() {
  return 'ProjectListState.loaded(projects: $projects, activityById: $activityById, isRefreshing: $isRefreshing)';
}


}

/// @nodoc
abstract mixin class $ProjectListLoadedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListLoadedCopyWith(ProjectListLoaded value, $Res Function(ProjectListLoaded) _then) = _$ProjectListLoadedCopyWithImpl;
@useResult
$Res call({
 List<Project> projects, Map<String, int> activityById, bool isRefreshing
});




}
/// @nodoc
class _$ProjectListLoadedCopyWithImpl<$Res>
    implements $ProjectListLoadedCopyWith<$Res> {
  _$ProjectListLoadedCopyWithImpl(this._self, this._then);

  final ProjectListLoaded _self;
  final $Res Function(ProjectListLoaded) _then;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projects = null,Object? activityById = null,Object? isRefreshing = null,}) {
  return _then(ProjectListLoaded(
projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<Project>,activityById: null == activityById ? _self._activityById : activityById // ignore: cast_nullable_to_non_nullable
as Map<String, int>,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ProjectListFailed implements ProjectListState {
  const ProjectListFailed({required this.error});
  

 final  ApiError error;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListFailedCopyWith<ProjectListFailed> get copyWith => _$ProjectListFailedCopyWithImpl<ProjectListFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'ProjectListState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $ProjectListFailedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListFailedCopyWith(ProjectListFailed value, $Res Function(ProjectListFailed) _then) = _$ProjectListFailedCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$ProjectListFailedCopyWithImpl<$Res>
    implements $ProjectListFailedCopyWith<$Res> {
  _$ProjectListFailedCopyWithImpl(this._self, this._then);

  final ProjectListFailed _self;
  final $Res Function(ProjectListFailed) _then;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(ProjectListFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
