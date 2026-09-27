// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_launch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionLaunch {

 String get launchId; String get projectId; String get pluginId; DateTime get startedAt; Set<String> get followUpIds;
/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchCopyWith<SessionLaunch> get copyWith => _$SessionLaunchCopyWithImpl<SessionLaunch>(this as SessionLaunch, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionLaunch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunch&&(identical(other.launchId, _this.launchId) || other.launchId == _this.launchId)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.pluginId, _this.pluginId) || other.pluginId == _this.pluginId)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _this.followUpIds));
}


@override
int get hashCode {
  final _this = this as SessionLaunch;
  return Object.hash(runtimeType,_this.launchId,_this.projectId,_this.pluginId,_this.startedAt,const DeepCollectionEquality().hash(_this.followUpIds));
}

@override
String toString() {
  final _this = this as SessionLaunch;
  return 'SessionLaunch(launchId: ${_this.launchId}, projectId: ${_this.projectId}, pluginId: ${_this.pluginId}, startedAt: ${_this.startedAt}, followUpIds: ${_this.followUpIds})';
}


}

/// @nodoc
abstract mixin class $SessionLaunchCopyWith<$Res>  {
  factory $SessionLaunchCopyWith(SessionLaunch value, $Res Function(SessionLaunch) _then) = _$SessionLaunchCopyWithImpl;
@useResult
$Res call({
 String launchId, String projectId, String pluginId, DateTime startedAt, Set<String> followUpIds
});




}
/// @nodoc
class _$SessionLaunchCopyWithImpl<$Res>
    implements $SessionLaunchCopyWith<$Res> {
  _$SessionLaunchCopyWithImpl(this._self, this._then);

  final SessionLaunch _self;
  final $Res Function(SessionLaunch) _then;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? launchId = null,Object? projectId = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,}) {
  return _then(_self.copyWith(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self.followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}



/// @nodoc


class PendingSessionLaunch implements SessionLaunch {
  const PendingSessionLaunch({required this.launchId, required this.projectId, required this.pluginId, required this.startedAt, required  Set<String> followUpIds, required this.submission}): _followUpIds = followUpIds;
  

@override final  String launchId;
@override final  String projectId;
@override final  String pluginId;
@override final  DateTime startedAt;
 final  Set<String> _followUpIds;
@override Set<String> get followUpIds {
  if (_followUpIds is EqualUnmodifiableSetView) return _followUpIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_followUpIds);
}

 final  NewSessionSubmissionSnapshot? submission;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingSessionLaunchCopyWith<PendingSessionLaunch> get copyWith => _$PendingSessionLaunchCopyWithImpl<PendingSessionLaunch>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingSessionLaunch&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _followUpIds)&&(identical(other.submission, submission) || other.submission == submission));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,projectId,pluginId,startedAt,const DeepCollectionEquality().hash(_followUpIds),submission);
}

@override
String toString() {
    return 'SessionLaunch.pending(launchId: $launchId, projectId: $projectId, pluginId: $pluginId, startedAt: $startedAt, followUpIds: $followUpIds, submission: $submission)';
}


}

/// @nodoc
abstract mixin class $PendingSessionLaunchCopyWith<$Res> implements $SessionLaunchCopyWith<$Res> {
  factory $PendingSessionLaunchCopyWith(PendingSessionLaunch value, $Res Function(PendingSessionLaunch) _then) = _$PendingSessionLaunchCopyWithImpl;
@override @useResult
$Res call({
 String launchId, String projectId, String pluginId, DateTime startedAt, Set<String> followUpIds, NewSessionSubmissionSnapshot? submission
});


$NewSessionSubmissionSnapshotCopyWith<$Res>? get submission;

}
/// @nodoc
class _$PendingSessionLaunchCopyWithImpl<$Res>
    implements $PendingSessionLaunchCopyWith<$Res> {
  _$PendingSessionLaunchCopyWithImpl(this._self, this._then);

  final PendingSessionLaunch _self;
  final $Res Function(PendingSessionLaunch) _then;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? projectId = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,Object? submission = freezed,}) {
  return _then(PendingSessionLaunch(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self._followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,submission: freezed == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot?,
  ));
}

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<$Res>? get submission {
    if (_self.submission == null) {
    return null;
  }

  return $NewSessionSubmissionSnapshotCopyWith<$Res>(_self.submission!, (value) {
    return _then(_self.copyWith(submission: value));
  });
}
}

/// @nodoc


class CreatedSessionLaunch implements SessionLaunch {
  const CreatedSessionLaunch({required this.launchId, required this.projectId, required this.pluginId, required this.startedAt, required  Set<String> followUpIds, required this.session, required this.submission}): _followUpIds = followUpIds;
  

@override final  String launchId;
@override final  String projectId;
@override final  String pluginId;
@override final  DateTime startedAt;
 final  Set<String> _followUpIds;
@override Set<String> get followUpIds {
  if (_followUpIds is EqualUnmodifiableSetView) return _followUpIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_followUpIds);
}

 final  Session session;
 final  NewSessionSubmissionSnapshot submission;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreatedSessionLaunchCopyWith<CreatedSessionLaunch> get copyWith => _$CreatedSessionLaunchCopyWithImpl<CreatedSessionLaunch>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatedSessionLaunch&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _followUpIds)&&(identical(other.session, session) || other.session == session)&&(identical(other.submission, submission) || other.submission == submission));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,projectId,pluginId,startedAt,const DeepCollectionEquality().hash(_followUpIds),session,submission);
}

@override
String toString() {
    return 'SessionLaunch.created(launchId: $launchId, projectId: $projectId, pluginId: $pluginId, startedAt: $startedAt, followUpIds: $followUpIds, session: $session, submission: $submission)';
}


}

/// @nodoc
abstract mixin class $CreatedSessionLaunchCopyWith<$Res> implements $SessionLaunchCopyWith<$Res> {
  factory $CreatedSessionLaunchCopyWith(CreatedSessionLaunch value, $Res Function(CreatedSessionLaunch) _then) = _$CreatedSessionLaunchCopyWithImpl;
@override @useResult
$Res call({
 String launchId, String projectId, String pluginId, DateTime startedAt, Set<String> followUpIds, Session session, NewSessionSubmissionSnapshot submission
});


$SessionCopyWith<$Res> get session;$NewSessionSubmissionSnapshotCopyWith<$Res> get submission;

}
/// @nodoc
class _$CreatedSessionLaunchCopyWithImpl<$Res>
    implements $CreatedSessionLaunchCopyWith<$Res> {
  _$CreatedSessionLaunchCopyWithImpl(this._self, this._then);

  final CreatedSessionLaunch _self;
  final $Res Function(CreatedSessionLaunch) _then;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? projectId = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,Object? session = null,Object? submission = null,}) {
  return _then(CreatedSessionLaunch(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self._followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot,
  ));
}

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<$Res> get submission {
  
  return $NewSessionSubmissionSnapshotCopyWith<$Res>(_self.submission, (value) {
    return _then(_self.copyWith(submission: value));
  });
}
}

/// @nodoc


class ReconcilingSessionLaunch implements SessionLaunch {
  const ReconcilingSessionLaunch({required this.launchId, required this.projectId, required this.pluginId, required this.startedAt, required  Set<String> followUpIds, required this.session}): _followUpIds = followUpIds;
  

@override final  String launchId;
@override final  String projectId;
@override final  String pluginId;
@override final  DateTime startedAt;
 final  Set<String> _followUpIds;
@override Set<String> get followUpIds {
  if (_followUpIds is EqualUnmodifiableSetView) return _followUpIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_followUpIds);
}

 final  Session session;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReconcilingSessionLaunchCopyWith<ReconcilingSessionLaunch> get copyWith => _$ReconcilingSessionLaunchCopyWithImpl<ReconcilingSessionLaunch>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ReconcilingSessionLaunch&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _followUpIds)&&(identical(other.session, session) || other.session == session));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,projectId,pluginId,startedAt,const DeepCollectionEquality().hash(_followUpIds),session);
}

@override
String toString() {
    return 'SessionLaunch.reconciling(launchId: $launchId, projectId: $projectId, pluginId: $pluginId, startedAt: $startedAt, followUpIds: $followUpIds, session: $session)';
}


}

/// @nodoc
abstract mixin class $ReconcilingSessionLaunchCopyWith<$Res> implements $SessionLaunchCopyWith<$Res> {
  factory $ReconcilingSessionLaunchCopyWith(ReconcilingSessionLaunch value, $Res Function(ReconcilingSessionLaunch) _then) = _$ReconcilingSessionLaunchCopyWithImpl;
@override @useResult
$Res call({
 String launchId, String projectId, String pluginId, DateTime startedAt, Set<String> followUpIds, Session session
});


$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$ReconcilingSessionLaunchCopyWithImpl<$Res>
    implements $ReconcilingSessionLaunchCopyWith<$Res> {
  _$ReconcilingSessionLaunchCopyWithImpl(this._self, this._then);

  final ReconcilingSessionLaunch _self;
  final $Res Function(ReconcilingSessionLaunch) _then;

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? projectId = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,Object? session = null,}) {
  return _then(ReconcilingSessionLaunch(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self._followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SessionLaunch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

// dart format on
