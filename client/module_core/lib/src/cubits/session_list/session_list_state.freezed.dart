// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionListState {

 List<Session> get sessions;/// Map of active session ID -> activity info.
///
/// A session is "active" when either its main agent or any of its direct
/// child tasks are running.
 Map<String, SessionActivityInfo> get activeSessionIds;/// Map of session ID -> whether it has unseen changes (bold title). Merges
/// the REST-seeded `Session.unseen` with live `SesoriSessionUnseenChanged`
/// updates, the latter taking precedence.
 Map<String, bool> get unseenBySessionId;
/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListStateCopyWith<SessionListState> get copyWith => _$SessionListStateCopyWithImpl<SessionListState>(this as SessionListState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionListState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListState&&const DeepCollectionEquality().equals(other.sessions, _this.sessions)&&const DeepCollectionEquality().equals(other.activeSessionIds, _this.activeSessionIds)&&const DeepCollectionEquality().equals(other.unseenBySessionId, _this.unseenBySessionId));
}


@override
int get hashCode {
  final _this = this as SessionListState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sessions),const DeepCollectionEquality().hash(_this.activeSessionIds),const DeepCollectionEquality().hash(_this.unseenBySessionId));
}

@override
String toString() {
  final _this = this as SessionListState;
  return 'SessionListState(sessions: ${_this.sessions}, activeSessionIds: ${_this.activeSessionIds}, unseenBySessionId: ${_this.unseenBySessionId})';
}


}

/// @nodoc
abstract mixin class $SessionListStateCopyWith<$Res>  {
  factory $SessionListStateCopyWith(SessionListState value, $Res Function(SessionListState) _then) = _$SessionListStateCopyWithImpl;
@useResult
$Res call({
 List<Session> sessions, Map<String, SessionActivityInfo> activeSessionIds, Map<String, bool> unseenBySessionId
});




}
/// @nodoc
class _$SessionListStateCopyWithImpl<$Res>
    implements $SessionListStateCopyWith<$Res> {
  _$SessionListStateCopyWithImpl(this._self, this._then);

  final SessionListState _self;
  final $Res Function(SessionListState) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? activeSessionIds = null,Object? unseenBySessionId = null,}) {
  return _then(SessionListState(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,activeSessionIds: null == activeSessionIds ? _self.activeSessionIds : activeSessionIds // ignore: cast_nullable_to_non_nullable
as Map<String, SessionActivityInfo>,unseenBySessionId: null == unseenBySessionId ? _self.unseenBySessionId : unseenBySessionId // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}

}



/// @nodoc


class _SessionListState implements SessionListState {
  const _SessionListState({required  List<Session> sessions, required  Map<String, SessionActivityInfo> activeSessionIds, required  Map<String, bool> unseenBySessionId}): _sessions = sessions,_activeSessionIds = activeSessionIds,_unseenBySessionId = unseenBySessionId;
  

 final  List<Session> _sessions;
@override List<Session> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

/// Map of active session ID -> activity info.
///
/// A session is "active" when either its main agent or any of its direct
/// child tasks are running.
 final  Map<String, SessionActivityInfo> _activeSessionIds;
/// Map of active session ID -> activity info.
///
/// A session is "active" when either its main agent or any of its direct
/// child tasks are running.
@override Map<String, SessionActivityInfo> get activeSessionIds {
  if (_activeSessionIds is EqualUnmodifiableMapView) return _activeSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_activeSessionIds);
}

/// Map of session ID -> whether it has unseen changes (bold title). Merges
/// the REST-seeded `Session.unseen` with live `SesoriSessionUnseenChanged`
/// updates, the latter taking precedence.
 final  Map<String, bool> _unseenBySessionId;
/// Map of session ID -> whether it has unseen changes (bold title). Merges
/// the REST-seeded `Session.unseen` with live `SesoriSessionUnseenChanged`
/// updates, the latter taking precedence.
@override Map<String, bool> get unseenBySessionId {
  if (_unseenBySessionId is EqualUnmodifiableMapView) return _unseenBySessionId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unseenBySessionId);
}


/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListStateCopyWith<_SessionListState> get copyWith => __$SessionListStateCopyWithImpl<_SessionListState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListState&&const DeepCollectionEquality().equals(other.sessions, _sessions)&&const DeepCollectionEquality().equals(other.activeSessionIds, _activeSessionIds)&&const DeepCollectionEquality().equals(other.unseenBySessionId, _unseenBySessionId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),const DeepCollectionEquality().hash(_activeSessionIds),const DeepCollectionEquality().hash(_unseenBySessionId));
}

@override
String toString() {
    return 'SessionListState(sessions: $sessions, activeSessionIds: $activeSessionIds, unseenBySessionId: $unseenBySessionId)';
}


}

/// @nodoc
abstract mixin class _$SessionListStateCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory _$SessionListStateCopyWith(_SessionListState value, $Res Function(_SessionListState) _then) = __$SessionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<Session> sessions, Map<String, SessionActivityInfo> activeSessionIds, Map<String, bool> unseenBySessionId
});




}
/// @nodoc
class __$SessionListStateCopyWithImpl<$Res>
    implements _$SessionListStateCopyWith<$Res> {
  __$SessionListStateCopyWithImpl(this._self, this._then);

  final _SessionListState _self;
  final $Res Function(_SessionListState) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? activeSessionIds = null,Object? unseenBySessionId = null,}) {
  return _then(_SessionListState(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,activeSessionIds: null == activeSessionIds ? _self._activeSessionIds : activeSessionIds // ignore: cast_nullable_to_non_nullable
as Map<String, SessionActivityInfo>,unseenBySessionId: null == unseenBySessionId ? _self._unseenBySessionId : unseenBySessionId // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}


}

// dart format on
