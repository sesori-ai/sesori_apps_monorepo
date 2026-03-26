// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionListState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionListState()';
}


}

/// @nodoc
class $SessionListStateCopyWith<$Res>  {
$SessionListStateCopyWith(SessionListState _, $Res Function(SessionListState) __);
}



/// @nodoc


class SessionListLoading implements SessionListState {
  const SessionListLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionListState.loading()';
}


}




/// @nodoc


class SessionListLoaded implements SessionListState {
  const SessionListLoaded({required final  List<Session> sessions, this.showArchived = false, final  Map<String, SessionActivityInfo> activeSessionIds = const {}, this.isRefreshing = false}): _sessions = sessions,_activeSessionIds = activeSessionIds;
  

 final  List<Session> _sessions;
 List<Session> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

@JsonKey() final  bool showArchived;
/// Map of active session ID -> activity info.
///
/// A session is "active" when either its main agent or any of its direct
/// child tasks are running.
 final  Map<String, SessionActivityInfo> _activeSessionIds;
/// Map of active session ID -> activity info.
///
/// A session is "active" when either its main agent or any of its direct
/// child tasks are running.
@JsonKey() Map<String, SessionActivityInfo> get activeSessionIds {
  if (_activeSessionIds is EqualUnmodifiableMapView) return _activeSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_activeSessionIds);
}

@JsonKey() final  bool isRefreshing;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListLoadedCopyWith<SessionListLoaded> get copyWith => _$SessionListLoadedCopyWithImpl<SessionListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListLoaded&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.showArchived, showArchived) || other.showArchived == showArchived)&&const DeepCollectionEquality().equals(other._activeSessionIds, _activeSessionIds)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),showArchived,const DeepCollectionEquality().hash(_activeSessionIds),isRefreshing);

@override
String toString() {
  return 'SessionListState.loaded(sessions: $sessions, showArchived: $showArchived, activeSessionIds: $activeSessionIds, isRefreshing: $isRefreshing)';
}


}

/// @nodoc
abstract mixin class $SessionListLoadedCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory $SessionListLoadedCopyWith(SessionListLoaded value, $Res Function(SessionListLoaded) _then) = _$SessionListLoadedCopyWithImpl;
@useResult
$Res call({
 List<Session> sessions, bool showArchived, Map<String, SessionActivityInfo> activeSessionIds, bool isRefreshing
});




}
/// @nodoc
class _$SessionListLoadedCopyWithImpl<$Res>
    implements $SessionListLoadedCopyWith<$Res> {
  _$SessionListLoadedCopyWithImpl(this._self, this._then);

  final SessionListLoaded _self;
  final $Res Function(SessionListLoaded) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? showArchived = null,Object? activeSessionIds = null,Object? isRefreshing = null,}) {
  return _then(SessionListLoaded(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,showArchived: null == showArchived ? _self.showArchived : showArchived // ignore: cast_nullable_to_non_nullable
as bool,activeSessionIds: null == activeSessionIds ? _self._activeSessionIds : activeSessionIds // ignore: cast_nullable_to_non_nullable
as Map<String, SessionActivityInfo>,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class SessionListStaleProject implements SessionListState {
  const SessionListStaleProject({required this.resolvedProjectId});
  

/// The project ID the server actually resolved.
 final  String resolvedProjectId;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListStaleProjectCopyWith<SessionListStaleProject> get copyWith => _$SessionListStaleProjectCopyWithImpl<SessionListStaleProject>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListStaleProject&&(identical(other.resolvedProjectId, resolvedProjectId) || other.resolvedProjectId == resolvedProjectId));
}


@override
int get hashCode => Object.hash(runtimeType,resolvedProjectId);

@override
String toString() {
  return 'SessionListState.staleProject(resolvedProjectId: $resolvedProjectId)';
}


}

/// @nodoc
abstract mixin class $SessionListStaleProjectCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory $SessionListStaleProjectCopyWith(SessionListStaleProject value, $Res Function(SessionListStaleProject) _then) = _$SessionListStaleProjectCopyWithImpl;
@useResult
$Res call({
 String resolvedProjectId
});




}
/// @nodoc
class _$SessionListStaleProjectCopyWithImpl<$Res>
    implements $SessionListStaleProjectCopyWith<$Res> {
  _$SessionListStaleProjectCopyWithImpl(this._self, this._then);

  final SessionListStaleProject _self;
  final $Res Function(SessionListStaleProject) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? resolvedProjectId = null,}) {
  return _then(SessionListStaleProject(
resolvedProjectId: null == resolvedProjectId ? _self.resolvedProjectId : resolvedProjectId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SessionListFailed implements SessionListState {
  const SessionListFailed({required this.error});
  

 final  ApiError error;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListFailedCopyWith<SessionListFailed> get copyWith => _$SessionListFailedCopyWithImpl<SessionListFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'SessionListState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $SessionListFailedCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory $SessionListFailedCopyWith(SessionListFailed value, $Res Function(SessionListFailed) _then) = _$SessionListFailedCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$SessionListFailedCopyWithImpl<$Res>
    implements $SessionListFailedCopyWith<$Res> {
  _$SessionListFailedCopyWithImpl(this._self, this._then);

  final SessionListFailed _self;
  final $Res Function(SessionListFailed) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(SessionListFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of SessionListState
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
