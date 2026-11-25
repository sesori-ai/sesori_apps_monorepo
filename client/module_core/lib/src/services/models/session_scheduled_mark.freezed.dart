// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_scheduled_mark.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionScheduledMark {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMark);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionScheduledMark()';
}


}

/// @nodoc
class $SessionScheduledMarkCopyWith<$Res>  {
$SessionScheduledMarkCopyWith(SessionScheduledMark _, $Res Function(SessionScheduledMark) __);
}



/// @nodoc


class SessionScheduledMarkNone implements SessionScheduledMark {
  const SessionScheduledMarkNone();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMarkNone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionScheduledMark.none()';
}


}




/// @nodoc


class SessionScheduledMarkArmed implements SessionScheduledMark {
  const SessionScheduledMarkArmed({required this.name, required this.nextAt});
  

 final  String name;
 final  int nextAt;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionScheduledMarkArmedCopyWith<SessionScheduledMarkArmed> get copyWith => _$SessionScheduledMarkArmedCopyWithImpl<SessionScheduledMarkArmed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMarkArmed&&(identical(other.name, name) || other.name == name)&&(identical(other.nextAt, nextAt) || other.nextAt == nextAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,nextAt);
}

@override
String toString() {
    return 'SessionScheduledMark.armed(name: $name, nextAt: $nextAt)';
}


}

/// @nodoc
abstract mixin class $SessionScheduledMarkArmedCopyWith<$Res> implements $SessionScheduledMarkCopyWith<$Res> {
  factory $SessionScheduledMarkArmedCopyWith(SessionScheduledMarkArmed value, $Res Function(SessionScheduledMarkArmed) _then) = _$SessionScheduledMarkArmedCopyWithImpl;
@useResult
$Res call({
 String name, int nextAt
});




}
/// @nodoc
class _$SessionScheduledMarkArmedCopyWithImpl<$Res>
    implements $SessionScheduledMarkArmedCopyWith<$Res> {
  _$SessionScheduledMarkArmedCopyWithImpl(this._self, this._then);

  final SessionScheduledMarkArmed _self;
  final $Res Function(SessionScheduledMarkArmed) _then;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? nextAt = null,}) {
  return _then(SessionScheduledMarkArmed(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nextAt: null == nextAt ? _self.nextAt : nextAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class SessionScheduledMarkWatchingPullRequests implements SessionScheduledMark {
  const SessionScheduledMarkWatchingPullRequests({required this.lead, required this.others});
  

 final  SessionPullRequestWatch lead;
 final  int others;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionScheduledMarkWatchingPullRequestsCopyWith<SessionScheduledMarkWatchingPullRequests> get copyWith => _$SessionScheduledMarkWatchingPullRequestsCopyWithImpl<SessionScheduledMarkWatchingPullRequests>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMarkWatchingPullRequests&&(identical(other.lead, lead) || other.lead == lead)&&(identical(other.others, others) || other.others == others));
}


@override
int get hashCode {
    return Object.hash(runtimeType,lead,others);
}

@override
String toString() {
    return 'SessionScheduledMark.watchingPullRequests(lead: $lead, others: $others)';
}


}

/// @nodoc
abstract mixin class $SessionScheduledMarkWatchingPullRequestsCopyWith<$Res> implements $SessionScheduledMarkCopyWith<$Res> {
  factory $SessionScheduledMarkWatchingPullRequestsCopyWith(SessionScheduledMarkWatchingPullRequests value, $Res Function(SessionScheduledMarkWatchingPullRequests) _then) = _$SessionScheduledMarkWatchingPullRequestsCopyWithImpl;
@useResult
$Res call({
 SessionPullRequestWatch lead, int others
});


$SessionPullRequestWatchCopyWith<$Res> get lead;

}
/// @nodoc
class _$SessionScheduledMarkWatchingPullRequestsCopyWithImpl<$Res>
    implements $SessionScheduledMarkWatchingPullRequestsCopyWith<$Res> {
  _$SessionScheduledMarkWatchingPullRequestsCopyWithImpl(this._self, this._then);

  final SessionScheduledMarkWatchingPullRequests _self;
  final $Res Function(SessionScheduledMarkWatchingPullRequests) _then;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lead = null,Object? others = null,}) {
  return _then(SessionScheduledMarkWatchingPullRequests(
lead: null == lead ? _self.lead : lead // ignore: cast_nullable_to_non_nullable
as SessionPullRequestWatch,others: null == others ? _self.others : others // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPullRequestWatchCopyWith<$Res> get lead {
  
  return $SessionPullRequestWatchCopyWith<$Res>(_self.lead, (value) {
    return _then(_self.copyWith(lead: value));
  });
}
}

/// @nodoc


class SessionScheduledMarkFromTask implements SessionScheduledMark {
  const SessionScheduledMarkFromTask({required this.name});
  

 final  String name;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionScheduledMarkFromTaskCopyWith<SessionScheduledMarkFromTask> get copyWith => _$SessionScheduledMarkFromTaskCopyWithImpl<SessionScheduledMarkFromTask>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMarkFromTask&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'SessionScheduledMark.fromTask(name: $name)';
}


}

/// @nodoc
abstract mixin class $SessionScheduledMarkFromTaskCopyWith<$Res> implements $SessionScheduledMarkCopyWith<$Res> {
  factory $SessionScheduledMarkFromTaskCopyWith(SessionScheduledMarkFromTask value, $Res Function(SessionScheduledMarkFromTask) _then) = _$SessionScheduledMarkFromTaskCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$SessionScheduledMarkFromTaskCopyWithImpl<$Res>
    implements $SessionScheduledMarkFromTaskCopyWith<$Res> {
  _$SessionScheduledMarkFromTaskCopyWithImpl(this._self, this._then);

  final SessionScheduledMarkFromTask _self;
  final $Res Function(SessionScheduledMarkFromTask) _then;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(SessionScheduledMarkFromTask(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SessionScheduledMarkLegacyTask implements SessionScheduledMark {
  const SessionScheduledMarkLegacyTask({required this.task});
  

 final  SessionScheduledTaskMark task;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionScheduledMarkLegacyTaskCopyWith<SessionScheduledMarkLegacyTask> get copyWith => _$SessionScheduledMarkLegacyTaskCopyWithImpl<SessionScheduledMarkLegacyTask>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledMarkLegacyTask&&(identical(other.task, task) || other.task == task));
}


@override
int get hashCode {
    return Object.hash(runtimeType,task);
}

@override
String toString() {
    return 'SessionScheduledMark.legacyTask(task: $task)';
}


}

/// @nodoc
abstract mixin class $SessionScheduledMarkLegacyTaskCopyWith<$Res> implements $SessionScheduledMarkCopyWith<$Res> {
  factory $SessionScheduledMarkLegacyTaskCopyWith(SessionScheduledMarkLegacyTask value, $Res Function(SessionScheduledMarkLegacyTask) _then) = _$SessionScheduledMarkLegacyTaskCopyWithImpl;
@useResult
$Res call({
 SessionScheduledTaskMark task
});


$SessionScheduledTaskMarkCopyWith<$Res> get task;

}
/// @nodoc
class _$SessionScheduledMarkLegacyTaskCopyWithImpl<$Res>
    implements $SessionScheduledMarkLegacyTaskCopyWith<$Res> {
  _$SessionScheduledMarkLegacyTaskCopyWithImpl(this._self, this._then);

  final SessionScheduledMarkLegacyTask _self;
  final $Res Function(SessionScheduledMarkLegacyTask) _then;

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? task = null,}) {
  return _then(SessionScheduledMarkLegacyTask(
task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as SessionScheduledTaskMark,
  ));
}

/// Create a copy of SessionScheduledMark
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionScheduledTaskMarkCopyWith<$Res> get task {
  
  return $SessionScheduledTaskMarkCopyWith<$Res>(_self.task, (value) {
    return _then(_self.copyWith(task: value));
  });
}
}

// dart format on
