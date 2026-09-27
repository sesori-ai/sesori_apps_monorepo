// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_launch_handoff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionLaunchHandoff {

 NewSessionSubmissionSnapshot get submission;/// The harness the bubble names once the send runs long.
 String get pluginId;/// When Send committed, so the bubble's slow-send copy continues rather
/// than restarting on each widget the handoff passes through.
 DateTime get startedAt;/// Every promptId the launch minted for a follow-up. A bridge-queued prompt
/// with one of these ids is not the first message's replacement.
 Set<String> get followUpIds;
/// Create a copy of SessionLaunchHandoff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLaunchHandoffCopyWith<SessionLaunchHandoff> get copyWith => _$SessionLaunchHandoffCopyWithImpl<SessionLaunchHandoff>(this as SessionLaunchHandoff, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionLaunchHandoff;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLaunchHandoff&&(identical(other.submission, _this.submission) || other.submission == _this.submission)&&(identical(other.pluginId, _this.pluginId) || other.pluginId == _this.pluginId)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _this.followUpIds));
}


@override
int get hashCode {
  final _this = this as SessionLaunchHandoff;
  return Object.hash(runtimeType,_this.submission,_this.pluginId,_this.startedAt,const DeepCollectionEquality().hash(_this.followUpIds));
}

@override
String toString() {
  final _this = this as SessionLaunchHandoff;
  return 'SessionLaunchHandoff(submission: ${_this.submission}, pluginId: ${_this.pluginId}, startedAt: ${_this.startedAt}, followUpIds: ${_this.followUpIds})';
}


}

/// @nodoc
abstract mixin class $SessionLaunchHandoffCopyWith<$Res>  {
  factory $SessionLaunchHandoffCopyWith(SessionLaunchHandoff value, $Res Function(SessionLaunchHandoff) _then) = _$SessionLaunchHandoffCopyWithImpl;
@useResult
$Res call({
 NewSessionSubmissionSnapshot submission, String pluginId, DateTime startedAt, Set<String> followUpIds
});


$NewSessionSubmissionSnapshotCopyWith<$Res> get submission;

}
/// @nodoc
class _$SessionLaunchHandoffCopyWithImpl<$Res>
    implements $SessionLaunchHandoffCopyWith<$Res> {
  _$SessionLaunchHandoffCopyWithImpl(this._self, this._then);

  final SessionLaunchHandoff _self;
  final $Res Function(SessionLaunchHandoff) _then;

/// Create a copy of SessionLaunchHandoff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? submission = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,}) {
  return _then(SessionLaunchHandoff(
submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self.followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}
/// Create a copy of SessionLaunchHandoff
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


class _SessionLaunchHandoff implements SessionLaunchHandoff {
  const _SessionLaunchHandoff({required this.submission, required this.pluginId, required this.startedAt, required  Set<String> followUpIds}): _followUpIds = followUpIds;
  

@override final  NewSessionSubmissionSnapshot submission;
/// The harness the bubble names once the send runs long.
@override final  String pluginId;
/// When Send committed, so the bubble's slow-send copy continues rather
/// than restarting on each widget the handoff passes through.
@override final  DateTime startedAt;
/// Every promptId the launch minted for a follow-up. A bridge-queued prompt
/// with one of these ids is not the first message's replacement.
 final  Set<String> _followUpIds;
/// Every promptId the launch minted for a follow-up. A bridge-queued prompt
/// with one of these ids is not the first message's replacement.
@override Set<String> get followUpIds {
  if (_followUpIds is EqualUnmodifiableSetView) return _followUpIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_followUpIds);
}


/// Create a copy of SessionLaunchHandoff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionLaunchHandoffCopyWith<_SessionLaunchHandoff> get copyWith => __$SessionLaunchHandoffCopyWithImpl<_SessionLaunchHandoff>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionLaunchHandoff&&(identical(other.submission, submission) || other.submission == submission)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.followUpIds, _followUpIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,submission,pluginId,startedAt,const DeepCollectionEquality().hash(_followUpIds));
}

@override
String toString() {
    return 'SessionLaunchHandoff(submission: $submission, pluginId: $pluginId, startedAt: $startedAt, followUpIds: $followUpIds)';
}


}

/// @nodoc
abstract mixin class _$SessionLaunchHandoffCopyWith<$Res> implements $SessionLaunchHandoffCopyWith<$Res> {
  factory _$SessionLaunchHandoffCopyWith(_SessionLaunchHandoff value, $Res Function(_SessionLaunchHandoff) _then) = __$SessionLaunchHandoffCopyWithImpl;
@override @useResult
$Res call({
 NewSessionSubmissionSnapshot submission, String pluginId, DateTime startedAt, Set<String> followUpIds
});


@override $NewSessionSubmissionSnapshotCopyWith<$Res> get submission;

}
/// @nodoc
class __$SessionLaunchHandoffCopyWithImpl<$Res>
    implements _$SessionLaunchHandoffCopyWith<$Res> {
  __$SessionLaunchHandoffCopyWithImpl(this._self, this._then);

  final _SessionLaunchHandoff _self;
  final $Res Function(_SessionLaunchHandoff) _then;

/// Create a copy of SessionLaunchHandoff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? submission = null,Object? pluginId = null,Object? startedAt = null,Object? followUpIds = null,}) {
  return _then(_SessionLaunchHandoff(
submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUpIds: null == followUpIds ? _self._followUpIds : followUpIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

/// Create a copy of SessionLaunchHandoff
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<$Res> get submission {
  
  return $NewSessionSubmissionSnapshotCopyWith<$Res>(_self.submission, (value) {
    return _then(_self.copyWith(submission: value));
  });
}
}

// dart format on
