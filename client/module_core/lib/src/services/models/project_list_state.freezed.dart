// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
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
  const ProjectListLoaded({required  List<ProjectSummary> projects, required  List<ProjectSummary> folderProjects, required this.scratchProject,  Map<String, int> runningByProjectId = const {},  Map<String, bool> unseenByProjectId = const {}, this.isRefreshing = false}): _projects = projects,_folderProjects = folderProjects,_runningByProjectId = runningByProjectId,_unseenByProjectId = unseenByProjectId;
  

/// Every project, "No project" included: what a name lookup searches.
 final  List<ProjectSummary> _projects;
/// Every project, "No project" included: what a name lookup searches.
 List<ProjectSummary> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}

/// The folder projects of [projects], in its order: what a project list
/// shows.
 final  List<ProjectSummary> _folderProjects;
/// The folder projects of [projects], in its order: what a project list
/// shows.
 List<ProjectSummary> get folderProjects {
  if (_folderProjects is EqualUnmodifiableListView) return _folderProjects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_folderProjects);
}

/// The bridge's "No project" project, or null on a bridge without one.
 final  ProjectSummary? scratchProject;
/// Map of project ID -> its running root sessions. Projects with none are
/// absent; a session only waiting for input is not running.
 final  Map<String, int> _runningByProjectId;
/// Map of project ID -> its running root sessions. Projects with none are
/// absent; a session only waiting for input is not running.
@JsonKey() Map<String, int> get runningByProjectId {
  if (_runningByProjectId is EqualUnmodifiableMapView) return _runningByProjectId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_runningByProjectId);
}

/// Map of project ID -> whether it has unseen changes (bold title). Merges
/// the REST-seeded `Project.hasUnseenChanges` with live
/// `SesoriSessionUnseenChanged` updates, the latter taking precedence.
 final  Map<String, bool> _unseenByProjectId;
/// Map of project ID -> whether it has unseen changes (bold title). Merges
/// the REST-seeded `Project.hasUnseenChanges` with live
/// `SesoriSessionUnseenChanged` updates, the latter taking precedence.
@JsonKey() Map<String, bool> get unseenByProjectId {
  if (_unseenByProjectId is EqualUnmodifiableMapView) return _unseenByProjectId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unseenByProjectId);
}

@JsonKey() final  bool isRefreshing;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListLoadedCopyWith<ProjectListLoaded> get copyWith => _$ProjectListLoadedCopyWithImpl<ProjectListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListLoaded&&const DeepCollectionEquality().equals(other.projects, _projects)&&const DeepCollectionEquality().equals(other.folderProjects, _folderProjects)&&(identical(other.scratchProject, scratchProject) || other.scratchProject == scratchProject)&&const DeepCollectionEquality().equals(other.runningByProjectId, _runningByProjectId)&&const DeepCollectionEquality().equals(other.unseenByProjectId, _unseenByProjectId)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_projects),const DeepCollectionEquality().hash(_folderProjects),scratchProject,const DeepCollectionEquality().hash(_runningByProjectId),const DeepCollectionEquality().hash(_unseenByProjectId),isRefreshing);
}

@override
String toString() {
    return 'ProjectListState.loaded(projects: $projects, folderProjects: $folderProjects, scratchProject: $scratchProject, runningByProjectId: $runningByProjectId, unseenByProjectId: $unseenByProjectId, isRefreshing: $isRefreshing)';
}


}

/// @nodoc
abstract mixin class $ProjectListLoadedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListLoadedCopyWith(ProjectListLoaded value, $Res Function(ProjectListLoaded) _then) = _$ProjectListLoadedCopyWithImpl;
@useResult
$Res call({
 List<ProjectSummary> projects, List<ProjectSummary> folderProjects, ProjectSummary? scratchProject, Map<String, int> runningByProjectId, Map<String, bool> unseenByProjectId, bool isRefreshing
});


$ProjectSummaryCopyWith<$Res>? get scratchProject;

}
/// @nodoc
class _$ProjectListLoadedCopyWithImpl<$Res>
    implements $ProjectListLoadedCopyWith<$Res> {
  _$ProjectListLoadedCopyWithImpl(this._self, this._then);

  final ProjectListLoaded _self;
  final $Res Function(ProjectListLoaded) _then;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projects = null,Object? folderProjects = null,Object? scratchProject = freezed,Object? runningByProjectId = null,Object? unseenByProjectId = null,Object? isRefreshing = null,}) {
  return _then(ProjectListLoaded(
projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectSummary>,folderProjects: null == folderProjects ? _self._folderProjects : folderProjects // ignore: cast_nullable_to_non_nullable
as List<ProjectSummary>,scratchProject: freezed == scratchProject ? _self.scratchProject : scratchProject // ignore: cast_nullable_to_non_nullable
as ProjectSummary?,runningByProjectId: null == runningByProjectId ? _self._runningByProjectId : runningByProjectId // ignore: cast_nullable_to_non_nullable
as Map<String, int>,unseenByProjectId: null == unseenByProjectId ? _self._unseenByProjectId : unseenByProjectId // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<$Res>? get scratchProject {
    if (_self.scratchProject == null) {
    return null;
  }

  return $ProjectSummaryCopyWith<$Res>(_self.scratchProject!, (value) {
    return _then(_self.copyWith(scratchProject: value));
  });
}
}

/// @nodoc


class ProjectListFailed implements ProjectListState {
  const ProjectListFailed({required this.reason});
  

 final  RemoteFailureReason reason;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListFailedCopyWith<ProjectListFailed> get copyWith => _$ProjectListFailedCopyWithImpl<ProjectListFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListFailed&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'ProjectListState.failed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ProjectListFailedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListFailedCopyWith(ProjectListFailed value, $Res Function(ProjectListFailed) _then) = _$ProjectListFailedCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason
});




}
/// @nodoc
class _$ProjectListFailedCopyWithImpl<$Res>
    implements $ProjectListFailedCopyWith<$Res> {
  _$ProjectListFailedCopyWithImpl(this._self, this._then);

  final ProjectListFailed _self;
  final $Res Function(ProjectListFailed) _then;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(ProjectListFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

/// @nodoc


class ProjectListBridgeDisconnected implements ProjectListState {
  const ProjectListBridgeDisconnected({required this.hasRegisteredBridges});
  

 final  bool hasRegisteredBridges;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListBridgeDisconnectedCopyWith<ProjectListBridgeDisconnected> get copyWith => _$ProjectListBridgeDisconnectedCopyWithImpl<ProjectListBridgeDisconnected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListBridgeDisconnected&&(identical(other.hasRegisteredBridges, hasRegisteredBridges) || other.hasRegisteredBridges == hasRegisteredBridges));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hasRegisteredBridges);
}

@override
String toString() {
    return 'ProjectListState.bridgeDisconnected(hasRegisteredBridges: $hasRegisteredBridges)';
}


}

/// @nodoc
abstract mixin class $ProjectListBridgeDisconnectedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListBridgeDisconnectedCopyWith(ProjectListBridgeDisconnected value, $Res Function(ProjectListBridgeDisconnected) _then) = _$ProjectListBridgeDisconnectedCopyWithImpl;
@useResult
$Res call({
 bool hasRegisteredBridges
});




}
/// @nodoc
class _$ProjectListBridgeDisconnectedCopyWithImpl<$Res>
    implements $ProjectListBridgeDisconnectedCopyWith<$Res> {
  _$ProjectListBridgeDisconnectedCopyWithImpl(this._self, this._then);

  final ProjectListBridgeDisconnected _self;
  final $Res Function(ProjectListBridgeDisconnected) _then;

/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? hasRegisteredBridges = null,}) {
  return _then(ProjectListBridgeDisconnected(
hasRegisteredBridges: null == hasRegisteredBridges ? _self.hasRegisteredBridges : hasRegisteredBridges // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
