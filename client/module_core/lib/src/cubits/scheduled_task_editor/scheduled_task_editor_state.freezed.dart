// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_task_editor_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduledTaskEditorState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskEditorState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskEditorState()';
}


}

/// @nodoc
class $ScheduledTaskEditorStateCopyWith<$Res>  {
$ScheduledTaskEditorStateCopyWith(ScheduledTaskEditorState _, $Res Function(ScheduledTaskEditorState) __);
}



/// @nodoc


class ScheduledTaskEditorLoading implements ScheduledTaskEditorState {
  const ScheduledTaskEditorLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskEditorLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskEditorState.loading()';
}


}




/// @nodoc


class ScheduledTaskEditorUnavailable implements ScheduledTaskEditorState {
  const ScheduledTaskEditorUnavailable({required this.reason});
  

 final  ScheduledTaskEditorUnavailableReason reason;

/// Create a copy of ScheduledTaskEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskEditorUnavailableCopyWith<ScheduledTaskEditorUnavailable> get copyWith => _$ScheduledTaskEditorUnavailableCopyWithImpl<ScheduledTaskEditorUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskEditorUnavailable&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'ScheduledTaskEditorState.unavailable(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskEditorUnavailableCopyWith<$Res> implements $ScheduledTaskEditorStateCopyWith<$Res> {
  factory $ScheduledTaskEditorUnavailableCopyWith(ScheduledTaskEditorUnavailable value, $Res Function(ScheduledTaskEditorUnavailable) _then) = _$ScheduledTaskEditorUnavailableCopyWithImpl;
@useResult
$Res call({
 ScheduledTaskEditorUnavailableReason reason
});




}
/// @nodoc
class _$ScheduledTaskEditorUnavailableCopyWithImpl<$Res>
    implements $ScheduledTaskEditorUnavailableCopyWith<$Res> {
  _$ScheduledTaskEditorUnavailableCopyWithImpl(this._self, this._then);

  final ScheduledTaskEditorUnavailable _self;
  final $Res Function(ScheduledTaskEditorUnavailable) _then;

/// Create a copy of ScheduledTaskEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(ScheduledTaskEditorUnavailable(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as ScheduledTaskEditorUnavailableReason,
  ));
}


}

/// @nodoc


class ScheduledTaskEditorReady implements ScheduledTaskEditorState {
  const ScheduledTaskEditorReady({required this.editing, required this.schedule, required this.missedRunPolicy, required this.runMode, required this.approvalMode, required this.timeZone, required this.save});
  

/// The task being edited; null while setting up a new one.
 final  ScheduledTask? editing;
 final  TaskSchedule schedule;
/// Kept while the schedule is Once, which always runs when the computer
/// is back, so switching back to a repeat finds the choice unchanged.
 final  TaskMissedRunPolicy missedRunPolicy;
 final  TaskRunMode runMode;
 final  TaskApprovalMode approvalMode;
/// The IANA zone the times are in: this device's for a new task, the
/// task's own for an edit.
 final  String timeZone;
 final  ScheduledTaskEditorSave save;

/// Create a copy of ScheduledTaskEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskEditorReadyCopyWith<ScheduledTaskEditorReady> get copyWith => _$ScheduledTaskEditorReadyCopyWithImpl<ScheduledTaskEditorReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskEditorReady&&(identical(other.editing, editing) || other.editing == editing)&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.missedRunPolicy, missedRunPolicy) || other.missedRunPolicy == missedRunPolicy)&&(identical(other.runMode, runMode) || other.runMode == runMode)&&(identical(other.approvalMode, approvalMode) || other.approvalMode == approvalMode)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.save, save) || other.save == save));
}


@override
int get hashCode {
    return Object.hash(runtimeType,editing,schedule,missedRunPolicy,runMode,approvalMode,timeZone,save);
}

@override
String toString() {
    return 'ScheduledTaskEditorState.ready(editing: $editing, schedule: $schedule, missedRunPolicy: $missedRunPolicy, runMode: $runMode, approvalMode: $approvalMode, timeZone: $timeZone, save: $save)';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskEditorReadyCopyWith<$Res> implements $ScheduledTaskEditorStateCopyWith<$Res> {
  factory $ScheduledTaskEditorReadyCopyWith(ScheduledTaskEditorReady value, $Res Function(ScheduledTaskEditorReady) _then) = _$ScheduledTaskEditorReadyCopyWithImpl;
@useResult
$Res call({
 ScheduledTask? editing, TaskSchedule schedule, TaskMissedRunPolicy missedRunPolicy, TaskRunMode runMode, TaskApprovalMode approvalMode, String timeZone, ScheduledTaskEditorSave save
});


$ScheduledTaskCopyWith<$Res>? get editing;

}
/// @nodoc
class _$ScheduledTaskEditorReadyCopyWithImpl<$Res>
    implements $ScheduledTaskEditorReadyCopyWith<$Res> {
  _$ScheduledTaskEditorReadyCopyWithImpl(this._self, this._then);

  final ScheduledTaskEditorReady _self;
  final $Res Function(ScheduledTaskEditorReady) _then;

/// Create a copy of ScheduledTaskEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? editing = freezed,Object? schedule = null,Object? missedRunPolicy = null,Object? runMode = null,Object? approvalMode = null,Object? timeZone = null,Object? save = null,}) {
  return _then(ScheduledTaskEditorReady(
editing: freezed == editing ? _self.editing : editing // ignore: cast_nullable_to_non_nullable
as ScheduledTask?,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as TaskSchedule,missedRunPolicy: null == missedRunPolicy ? _self.missedRunPolicy : missedRunPolicy // ignore: cast_nullable_to_non_nullable
as TaskMissedRunPolicy,runMode: null == runMode ? _self.runMode : runMode // ignore: cast_nullable_to_non_nullable
as TaskRunMode,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as TaskApprovalMode,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,save: null == save ? _self.save : save // ignore: cast_nullable_to_non_nullable
as ScheduledTaskEditorSave,
  ));
}

/// Create a copy of ScheduledTaskEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskCopyWith<$Res>? get editing {
    if (_self.editing == null) {
    return null;
  }

  return $ScheduledTaskCopyWith<$Res>(_self.editing!, (value) {
    return _then(_self.copyWith(editing: value));
  });
}
}

// dart format on
