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
  const ProjectListLoaded({required final  List<Project> projects, required final  Map<String, int> activityById, final  Map<String, bool> unseenByProjectId = const {}, this.isRefreshing = false, final  List<BridgeSummary> bridges = const <BridgeSummary>[]}): _projects = projects,_activityById = activityById,_unseenByProjectId = unseenByProjectId,_bridges = bridges;
  

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
/// The account's registered bridges (most recently seen first), so the
/// connected-but-empty body can name the machine it is connected to.
/// Populated only while [projects] is empty — the only surface that shows
/// the machine identity. Emitted empty first and enriched by a follow-up
/// emit once the fetch resolves; stays empty when the fetch fails, which
/// hides the machine-name row.
 final  List<BridgeSummary> _bridges;
/// The account's registered bridges (most recently seen first), so the
/// connected-but-empty body can name the machine it is connected to.
/// Populated only while [projects] is empty — the only surface that shows
/// the machine identity. Emitted empty first and enriched by a follow-up
/// emit once the fetch resolves; stays empty when the fetch fails, which
/// hides the machine-name row.
@JsonKey() List<BridgeSummary> get bridges {
  if (_bridges is EqualUnmodifiableListView) return _bridges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bridges);
}


/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListLoadedCopyWith<ProjectListLoaded> get copyWith => _$ProjectListLoadedCopyWithImpl<ProjectListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListLoaded&&const DeepCollectionEquality().equals(other._projects, _projects)&&const DeepCollectionEquality().equals(other._activityById, _activityById)&&const DeepCollectionEquality().equals(other._unseenByProjectId, _unseenByProjectId)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&const DeepCollectionEquality().equals(other._bridges, _bridges));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_projects),const DeepCollectionEquality().hash(_activityById),const DeepCollectionEquality().hash(_unseenByProjectId),isRefreshing,const DeepCollectionEquality().hash(_bridges));

@override
String toString() {
  return 'ProjectListState.loaded(projects: $projects, activityById: $activityById, unseenByProjectId: $unseenByProjectId, isRefreshing: $isRefreshing, bridges: $bridges)';
}


}

/// @nodoc
abstract mixin class $ProjectListLoadedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListLoadedCopyWith(ProjectListLoaded value, $Res Function(ProjectListLoaded) _then) = _$ProjectListLoadedCopyWithImpl;
@useResult
$Res call({
 List<Project> projects, Map<String, int> activityById, Map<String, bool> unseenByProjectId, bool isRefreshing, List<BridgeSummary> bridges
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
@pragma('vm:prefer-inline') $Res call({Object? projects = null,Object? activityById = null,Object? unseenByProjectId = null,Object? isRefreshing = null,Object? bridges = null,}) {
  return _then(ProjectListLoaded(
projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<Project>,activityById: null == activityById ? _self._activityById : activityById // ignore: cast_nullable_to_non_nullable
as Map<String, int>,unseenByProjectId: null == unseenByProjectId ? _self._unseenByProjectId : unseenByProjectId // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,bridges: null == bridges ? _self._bridges : bridges // ignore: cast_nullable_to_non_nullable
as List<BridgeSummary>,
  ));
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
int get hashCode => Object.hash(runtimeType,reason);

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
  const ProjectListBridgeDisconnected({required this.hasRegisteredBridges, final  List<BridgeSummary> bridges = const <BridgeSummary>[]}): _bridges = bridges;
  

 final  bool hasRegisteredBridges;
/// The account's registered bridges (most recently seen first), so the UI
/// can name the machine it is trying to reach. Emitted empty first and
/// enriched by a follow-up emit once the fetch resolves; stays empty when
/// the fetch fails (e.g. the phone itself is offline) — the UI hides the
/// machine identity in that case.
 final  List<BridgeSummary> _bridges;
/// The account's registered bridges (most recently seen first), so the UI
/// can name the machine it is trying to reach. Emitted empty first and
/// enriched by a follow-up emit once the fetch resolves; stays empty when
/// the fetch fails (e.g. the phone itself is offline) — the UI hides the
/// machine identity in that case.
@JsonKey() List<BridgeSummary> get bridges {
  if (_bridges is EqualUnmodifiableListView) return _bridges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bridges);
}


/// Create a copy of ProjectListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListBridgeDisconnectedCopyWith<ProjectListBridgeDisconnected> get copyWith => _$ProjectListBridgeDisconnectedCopyWithImpl<ProjectListBridgeDisconnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListBridgeDisconnected&&(identical(other.hasRegisteredBridges, hasRegisteredBridges) || other.hasRegisteredBridges == hasRegisteredBridges)&&const DeepCollectionEquality().equals(other._bridges, _bridges));
}


@override
int get hashCode => Object.hash(runtimeType,hasRegisteredBridges,const DeepCollectionEquality().hash(_bridges));

@override
String toString() {
  return 'ProjectListState.bridgeDisconnected(hasRegisteredBridges: $hasRegisteredBridges, bridges: $bridges)';
}


}

/// @nodoc
abstract mixin class $ProjectListBridgeDisconnectedCopyWith<$Res> implements $ProjectListStateCopyWith<$Res> {
  factory $ProjectListBridgeDisconnectedCopyWith(ProjectListBridgeDisconnected value, $Res Function(ProjectListBridgeDisconnected) _then) = _$ProjectListBridgeDisconnectedCopyWithImpl;
@useResult
$Res call({
 bool hasRegisteredBridges, List<BridgeSummary> bridges
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
@pragma('vm:prefer-inline') $Res call({Object? hasRegisteredBridges = null,Object? bridges = null,}) {
  return _then(ProjectListBridgeDisconnected(
hasRegisteredBridges: null == hasRegisteredBridges ? _self.hasRegisteredBridges : hasRegisteredBridges // ignore: cast_nullable_to_non_nullable
as bool,bridges: null == bridges ? _self._bridges : bridges // ignore: cast_nullable_to_non_nullable
as List<BridgeSummary>,
  ));
}


}

// dart format on
