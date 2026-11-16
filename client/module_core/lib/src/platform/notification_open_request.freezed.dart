// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_open_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationOpenTarget {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationOpenTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NotificationOpenTarget()';
}


}

/// @nodoc
class $NotificationOpenTargetCopyWith<$Res>  {
$NotificationOpenTargetCopyWith(NotificationOpenTarget _, $Res Function(NotificationOpenTarget) __);
}



/// @nodoc


class NotificationOpenSession implements NotificationOpenTarget {
  const NotificationOpenSession({required this.projectId, required this.sessionId, required this.sessionTitle});
  

 final  String projectId;
 final  String sessionId;
 final  String? sessionTitle;

/// Create a copy of NotificationOpenTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationOpenSessionCopyWith<NotificationOpenSession> get copyWith => _$NotificationOpenSessionCopyWithImpl<NotificationOpenSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationOpenSession&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,projectId,sessionId,sessionTitle);
}

@override
String toString() {
    return 'NotificationOpenTarget.session(projectId: $projectId, sessionId: $sessionId, sessionTitle: $sessionTitle)';
}


}

/// @nodoc
abstract mixin class $NotificationOpenSessionCopyWith<$Res> implements $NotificationOpenTargetCopyWith<$Res> {
  factory $NotificationOpenSessionCopyWith(NotificationOpenSession value, $Res Function(NotificationOpenSession) _then) = _$NotificationOpenSessionCopyWithImpl;
@useResult
$Res call({
 String projectId, String sessionId, String? sessionTitle
});




}
/// @nodoc
class _$NotificationOpenSessionCopyWithImpl<$Res>
    implements $NotificationOpenSessionCopyWith<$Res> {
  _$NotificationOpenSessionCopyWithImpl(this._self, this._then);

  final NotificationOpenSession _self;
  final $Res Function(NotificationOpenSession) _then;

/// Create a copy of NotificationOpenTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? sessionId = null,Object? sessionTitle = freezed,}) {
  return _then(NotificationOpenSession(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class NotificationOpenTask implements NotificationOpenTarget {
  const NotificationOpenTask({required this.taskId});
  

 final  String taskId;

/// Create a copy of NotificationOpenTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationOpenTaskCopyWith<NotificationOpenTask> get copyWith => _$NotificationOpenTaskCopyWithImpl<NotificationOpenTask>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationOpenTask&&(identical(other.taskId, taskId) || other.taskId == taskId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,taskId);
}

@override
String toString() {
    return 'NotificationOpenTarget.task(taskId: $taskId)';
}


}

/// @nodoc
abstract mixin class $NotificationOpenTaskCopyWith<$Res> implements $NotificationOpenTargetCopyWith<$Res> {
  factory $NotificationOpenTaskCopyWith(NotificationOpenTask value, $Res Function(NotificationOpenTask) _then) = _$NotificationOpenTaskCopyWithImpl;
@useResult
$Res call({
 String taskId
});




}
/// @nodoc
class _$NotificationOpenTaskCopyWithImpl<$Res>
    implements $NotificationOpenTaskCopyWith<$Res> {
  _$NotificationOpenTaskCopyWithImpl(this._self, this._then);

  final NotificationOpenTask _self;
  final $Res Function(NotificationOpenTask) _then;

/// Create a copy of NotificationOpenTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? taskId = null,}) {
  return _then(NotificationOpenTask(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
