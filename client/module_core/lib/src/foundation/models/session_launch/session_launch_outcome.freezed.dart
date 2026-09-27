// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_launch_outcome.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionLaunchOutcome {

 String get launchId;
/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchOutcomeCopyWith<SessionLaunchOutcome> get copyWith => _$SessionLaunchOutcomeCopyWithImpl<SessionLaunchOutcome>(this as SessionLaunchOutcome, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionLaunchOutcome;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunchOutcome&&(identical(other.launchId, _this.launchId) || other.launchId == _this.launchId));
}


@override
int get hashCode {
  final _this = this as SessionLaunchOutcome;
  return Object.hash(runtimeType,_this.launchId);
}

@override
String toString() {
  final _this = this as SessionLaunchOutcome;
  return 'SessionLaunchOutcome(launchId: ${_this.launchId})';
}


}

/// @nodoc
abstract mixin class $SessionLaunchOutcomeCopyWith<$Res>  {
  factory $SessionLaunchOutcomeCopyWith(SessionLaunchOutcome value, $Res Function(SessionLaunchOutcome) _then) = _$SessionLaunchOutcomeCopyWithImpl;
@useResult
$Res call({
 String launchId
});




}
/// @nodoc
class _$SessionLaunchOutcomeCopyWithImpl<$Res>
    implements $SessionLaunchOutcomeCopyWith<$Res> {
  _$SessionLaunchOutcomeCopyWithImpl(this._self, this._then);

  final SessionLaunchOutcome _self;
  final $Res Function(SessionLaunchOutcome) _then;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? launchId = null,}) {
  return _then(_self.copyWith(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc


class SessionLaunchSucceeded implements SessionLaunchOutcome {
  const SessionLaunchSucceeded({required this.launchId, required this.session});
  

@override final  String launchId;
 final  Session session;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchSucceededCopyWith<SessionLaunchSucceeded> get copyWith => _$SessionLaunchSucceededCopyWithImpl<SessionLaunchSucceeded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunchSucceeded&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.session, session) || other.session == session));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,session);
}

@override
String toString() {
    return 'SessionLaunchOutcome.succeeded(launchId: $launchId, session: $session)';
}


}

/// @nodoc
abstract mixin class $SessionLaunchSucceededCopyWith<$Res> implements $SessionLaunchOutcomeCopyWith<$Res> {
  factory $SessionLaunchSucceededCopyWith(SessionLaunchSucceeded value, $Res Function(SessionLaunchSucceeded) _then) = _$SessionLaunchSucceededCopyWithImpl;
@override @useResult
$Res call({
 String launchId, Session session
});


$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$SessionLaunchSucceededCopyWithImpl<$Res>
    implements $SessionLaunchSucceededCopyWith<$Res> {
  _$SessionLaunchSucceededCopyWithImpl(this._self, this._then);

  final SessionLaunchSucceeded _self;
  final $Res Function(SessionLaunchSucceeded) _then;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? session = null,}) {
  return _then(SessionLaunchSucceeded(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

/// @nodoc


class SessionLaunchFailedWhileComposing implements SessionLaunchOutcome {
  const SessionLaunchFailedWhileComposing({required this.launchId, required this.reason});
  

@override final  String launchId;
 final  RemoteFailureReason reason;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchFailedWhileComposingCopyWith<SessionLaunchFailedWhileComposing> get copyWith => _$SessionLaunchFailedWhileComposingCopyWithImpl<SessionLaunchFailedWhileComposing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunchFailedWhileComposing&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,reason);
}

@override
String toString() {
    return 'SessionLaunchOutcome.failedWhileComposing(launchId: $launchId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionLaunchFailedWhileComposingCopyWith<$Res> implements $SessionLaunchOutcomeCopyWith<$Res> {
  factory $SessionLaunchFailedWhileComposingCopyWith(SessionLaunchFailedWhileComposing value, $Res Function(SessionLaunchFailedWhileComposing) _then) = _$SessionLaunchFailedWhileComposingCopyWithImpl;
@override @useResult
$Res call({
 String launchId, RemoteFailureReason reason
});




}
/// @nodoc
class _$SessionLaunchFailedWhileComposingCopyWithImpl<$Res>
    implements $SessionLaunchFailedWhileComposingCopyWith<$Res> {
  _$SessionLaunchFailedWhileComposingCopyWithImpl(this._self, this._then);

  final SessionLaunchFailedWhileComposing _self;
  final $Res Function(SessionLaunchFailedWhileComposing) _then;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? reason = null,}) {
  return _then(SessionLaunchFailedWhileComposing(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

/// @nodoc


class SessionLaunchFailedAfterLeaving implements SessionLaunchOutcome {
  const SessionLaunchFailedAfterLeaving({required this.launchId, required this.projectId, required this.reason});
  

@override final  String launchId;
 final  String projectId;
 final  RemoteFailureReason reason;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchFailedAfterLeavingCopyWith<SessionLaunchFailedAfterLeaving> get copyWith => _$SessionLaunchFailedAfterLeavingCopyWithImpl<SessionLaunchFailedAfterLeaving>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunchFailedAfterLeaving&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launchId,projectId,reason);
}

@override
String toString() {
    return 'SessionLaunchOutcome.failedAfterLeaving(launchId: $launchId, projectId: $projectId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionLaunchFailedAfterLeavingCopyWith<$Res> implements $SessionLaunchOutcomeCopyWith<$Res> {
  factory $SessionLaunchFailedAfterLeavingCopyWith(SessionLaunchFailedAfterLeaving value, $Res Function(SessionLaunchFailedAfterLeaving) _then) = _$SessionLaunchFailedAfterLeavingCopyWithImpl;
@override @useResult
$Res call({
 String launchId, String projectId, RemoteFailureReason reason
});




}
/// @nodoc
class _$SessionLaunchFailedAfterLeavingCopyWithImpl<$Res>
    implements $SessionLaunchFailedAfterLeavingCopyWith<$Res> {
  _$SessionLaunchFailedAfterLeavingCopyWithImpl(this._self, this._then);

  final SessionLaunchFailedAfterLeaving _self;
  final $Res Function(SessionLaunchFailedAfterLeaving) _then;

/// Create a copy of SessionLaunchOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launchId = null,Object? projectId = null,Object? reason = null,}) {
  return _then(SessionLaunchFailedAfterLeaving(
launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

// dart format on
