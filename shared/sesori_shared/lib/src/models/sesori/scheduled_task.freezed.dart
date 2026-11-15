// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduledTask {

 String get id; ScheduledTaskDefinition get definition;/// Whether the task runs on its schedule. A paused task keeps its
/// definition and can still be run now.
 bool get enabled;/// When the task runs next. Null while it is paused or has nothing left to
/// run.
 ScheduledTaskInstant? get nextRunAt;/// The newest run row, including skipped, missed and failed ones. Null
/// before the first run.
 ScheduledTaskRun? get lastRun;
/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskCopyWith<ScheduledTask> get copyWith => _$ScheduledTaskCopyWithImpl<ScheduledTask>(this as ScheduledTask, _$identity);

  /// Serializes this ScheduledTask to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTask;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTask&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.definition, _this.definition) || other.definition == _this.definition)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.nextRunAt, _this.nextRunAt) || other.nextRunAt == _this.nextRunAt)&&(identical(other.lastRun, _this.lastRun) || other.lastRun == _this.lastRun));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTask;
  return Object.hash(runtimeType,_this.id,_this.definition,_this.enabled,_this.nextRunAt,_this.lastRun);
}

@override
String toString() {
  final _this = this as ScheduledTask;
  return 'ScheduledTask(id: ${_this.id}, definition: ${_this.definition}, enabled: ${_this.enabled}, nextRunAt: ${_this.nextRunAt}, lastRun: ${_this.lastRun})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskCopyWith<$Res>  {
  factory $ScheduledTaskCopyWith(ScheduledTask value, $Res Function(ScheduledTask) _then) = _$ScheduledTaskCopyWithImpl;
@useResult
$Res call({
 String id, ScheduledTaskDefinition definition, bool enabled, ScheduledTaskInstant? nextRunAt, ScheduledTaskRun? lastRun
});


$ScheduledTaskDefinitionCopyWith<$Res> get definition;$ScheduledTaskInstantCopyWith<$Res>? get nextRunAt;$ScheduledTaskRunCopyWith<$Res>? get lastRun;

}
/// @nodoc
class _$ScheduledTaskCopyWithImpl<$Res>
    implements $ScheduledTaskCopyWith<$Res> {
  _$ScheduledTaskCopyWithImpl(this._self, this._then);

  final ScheduledTask _self;
  final $Res Function(ScheduledTask) _then;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? definition = null,Object? enabled = null,Object? nextRunAt = freezed,Object? lastRun = freezed,}) {
  return _then(ScheduledTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,nextRunAt: freezed == nextRunAt ? _self.nextRunAt : nextRunAt // ignore: cast_nullable_to_non_nullable
as ScheduledTaskInstant?,lastRun: freezed == lastRun ? _self.lastRun : lastRun // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRun?,
  ));
}
/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskInstantCopyWith<$Res>? get nextRunAt {
    if (_self.nextRunAt == null) {
    return null;
  }

  return $ScheduledTaskInstantCopyWith<$Res>(_self.nextRunAt!, (value) {
    return _then(_self.copyWith(nextRunAt: value));
  });
}/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskRunCopyWith<$Res>? get lastRun {
    if (_self.lastRun == null) {
    return null;
  }

  return $ScheduledTaskRunCopyWith<$Res>(_self.lastRun!, (value) {
    return _then(_self.copyWith(lastRun: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ScheduledTask implements ScheduledTask {
  const _ScheduledTask({required this.id, required this.definition, required this.enabled, required this.nextRunAt, required this.lastRun});
  factory _ScheduledTask.fromJson(Map<String, dynamic> json) => _$ScheduledTaskFromJson(json);

@override final  String id;
@override final  ScheduledTaskDefinition definition;
/// Whether the task runs on its schedule. A paused task keeps its
/// definition and can still be run now.
@override final  bool enabled;
/// When the task runs next. Null while it is paused or has nothing left to
/// run.
@override final  ScheduledTaskInstant? nextRunAt;
/// The newest run row, including skipped, missed and failed ones. Null
/// before the first run.
@override final  ScheduledTaskRun? lastRun;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskCopyWith<_ScheduledTask> get copyWith => __$ScheduledTaskCopyWithImpl<_ScheduledTask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTask&&(identical(other.id, id) || other.id == id)&&(identical(other.definition, definition) || other.definition == definition)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.nextRunAt, nextRunAt) || other.nextRunAt == nextRunAt)&&(identical(other.lastRun, lastRun) || other.lastRun == lastRun));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,definition,enabled,nextRunAt,lastRun);
}

@override
String toString() {
    return 'ScheduledTask(id: $id, definition: $definition, enabled: $enabled, nextRunAt: $nextRunAt, lastRun: $lastRun)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskCopyWith<$Res> implements $ScheduledTaskCopyWith<$Res> {
  factory _$ScheduledTaskCopyWith(_ScheduledTask value, $Res Function(_ScheduledTask) _then) = __$ScheduledTaskCopyWithImpl;
@override @useResult
$Res call({
 String id, ScheduledTaskDefinition definition, bool enabled, ScheduledTaskInstant? nextRunAt, ScheduledTaskRun? lastRun
});


@override $ScheduledTaskDefinitionCopyWith<$Res> get definition;@override $ScheduledTaskInstantCopyWith<$Res>? get nextRunAt;@override $ScheduledTaskRunCopyWith<$Res>? get lastRun;

}
/// @nodoc
class __$ScheduledTaskCopyWithImpl<$Res>
    implements _$ScheduledTaskCopyWith<$Res> {
  __$ScheduledTaskCopyWithImpl(this._self, this._then);

  final _ScheduledTask _self;
  final $Res Function(_ScheduledTask) _then;

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? definition = null,Object? enabled = null,Object? nextRunAt = freezed,Object? lastRun = freezed,}) {
  return _then(_ScheduledTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,nextRunAt: freezed == nextRunAt ? _self.nextRunAt : nextRunAt // ignore: cast_nullable_to_non_nullable
as ScheduledTaskInstant?,lastRun: freezed == lastRun ? _self.lastRun : lastRun // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRun?,
  ));
}

/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskInstantCopyWith<$Res>? get nextRunAt {
    if (_self.nextRunAt == null) {
    return null;
  }

  return $ScheduledTaskInstantCopyWith<$Res>(_self.nextRunAt!, (value) {
    return _then(_self.copyWith(nextRunAt: value));
  });
}/// Create a copy of ScheduledTask
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskRunCopyWith<$Res>? get lastRun {
    if (_self.lastRun == null) {
    return null;
  }

  return $ScheduledTaskRunCopyWith<$Res>(_self.lastRun!, (value) {
    return _then(_self.copyWith(lastRun: value));
  });
}
}


/// @nodoc
mixin _$ScheduledTaskDefinition {

/// Shown on the Scheduled page, run marks and pushes. Defaults to the
/// prompt's first line in the editor.
 String get name; ScheduledTaskPrompt get prompt; String get projectId; String get pluginId; String? get agent; PromptModel? get model; SessionVariant? get variant; bool get fastMode;/// Whether each new-session run gets its own worktree. A same-session task
/// keeps the one its session started with.
 bool get dedicatedWorktree; TaskSchedule get schedule;/// IANA zone name, such as `Europe/Bucharest`. Every [schedule] time is a
/// wall-clock time in this zone, whatever zone the bridge's computer uses.
 String get timeZone;/// What happens when the bridge was off or asleep at a recurring run's
/// time. A one-off task always runs when the bridge is back.
@JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) TaskMissedRunPolicy get missedRunPolicy; TaskRunMode get runMode;@JsonKey(unknownEnumValue: TaskApprovalMode.unknown) TaskApprovalMode get approvalMode;
/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<ScheduledTaskDefinition> get copyWith => _$ScheduledTaskDefinitionCopyWithImpl<ScheduledTaskDefinition>(this as ScheduledTaskDefinition, _$identity);

  /// Serializes this ScheduledTaskDefinition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskDefinition;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskDefinition&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.pluginId, _this.pluginId) || other.pluginId == _this.pluginId)&&(identical(other.agent, _this.agent) || other.agent == _this.agent)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.variant, _this.variant) || other.variant == _this.variant)&&(identical(other.fastMode, _this.fastMode) || other.fastMode == _this.fastMode)&&(identical(other.dedicatedWorktree, _this.dedicatedWorktree) || other.dedicatedWorktree == _this.dedicatedWorktree)&&(identical(other.schedule, _this.schedule) || other.schedule == _this.schedule)&&(identical(other.timeZone, _this.timeZone) || other.timeZone == _this.timeZone)&&(identical(other.missedRunPolicy, _this.missedRunPolicy) || other.missedRunPolicy == _this.missedRunPolicy)&&(identical(other.runMode, _this.runMode) || other.runMode == _this.runMode)&&(identical(other.approvalMode, _this.approvalMode) || other.approvalMode == _this.approvalMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskDefinition;
  return Object.hash(runtimeType,_this.name,_this.prompt,_this.projectId,_this.pluginId,_this.agent,_this.model,_this.variant,_this.fastMode,_this.dedicatedWorktree,_this.schedule,_this.timeZone,_this.missedRunPolicy,_this.runMode,_this.approvalMode);
}

@override
String toString() {
  final _this = this as ScheduledTaskDefinition;
  return 'ScheduledTaskDefinition(name: ${_this.name}, prompt: ${_this.prompt}, projectId: ${_this.projectId}, pluginId: ${_this.pluginId}, agent: ${_this.agent}, model: ${_this.model}, variant: ${_this.variant}, fastMode: ${_this.fastMode}, dedicatedWorktree: ${_this.dedicatedWorktree}, schedule: ${_this.schedule}, timeZone: ${_this.timeZone}, missedRunPolicy: ${_this.missedRunPolicy}, runMode: ${_this.runMode}, approvalMode: ${_this.approvalMode})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskDefinitionCopyWith<$Res>  {
  factory $ScheduledTaskDefinitionCopyWith(ScheduledTaskDefinition value, $Res Function(ScheduledTaskDefinition) _then) = _$ScheduledTaskDefinitionCopyWithImpl;
@useResult
$Res call({
 String name, ScheduledTaskPrompt prompt, String projectId, String pluginId, String? agent, PromptModel? model, SessionVariant? variant, bool fastMode, bool dedicatedWorktree, TaskSchedule schedule, String timeZone,@JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) TaskMissedRunPolicy missedRunPolicy, TaskRunMode runMode,@JsonKey(unknownEnumValue: TaskApprovalMode.unknown) TaskApprovalMode approvalMode
});


$PromptModelCopyWith<$Res>? get model;$SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class _$ScheduledTaskDefinitionCopyWithImpl<$Res>
    implements $ScheduledTaskDefinitionCopyWith<$Res> {
  _$ScheduledTaskDefinitionCopyWithImpl(this._self, this._then);

  final ScheduledTaskDefinition _self;
  final $Res Function(ScheduledTaskDefinition) _then;

/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? prompt = null,Object? projectId = null,Object? pluginId = null,Object? agent = freezed,Object? model = freezed,Object? variant = freezed,Object? fastMode = null,Object? dedicatedWorktree = null,Object? schedule = null,Object? timeZone = null,Object? missedRunPolicy = null,Object? runMode = null,Object? approvalMode = null,}) {
  return _then(ScheduledTaskDefinition(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as ScheduledTaskPrompt,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,fastMode: null == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as bool,dedicatedWorktree: null == dedicatedWorktree ? _self.dedicatedWorktree : dedicatedWorktree // ignore: cast_nullable_to_non_nullable
as bool,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as TaskSchedule,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,missedRunPolicy: null == missedRunPolicy ? _self.missedRunPolicy : missedRunPolicy // ignore: cast_nullable_to_non_nullable
as TaskMissedRunPolicy,runMode: null == runMode ? _self.runMode : runMode // ignore: cast_nullable_to_non_nullable
as TaskRunMode,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as TaskApprovalMode,
  ));
}
/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res>? get variant {
    if (_self.variant == null) {
    return null;
  }

  return $SessionVariantCopyWith<$Res>(_self.variant!, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskDefinition implements ScheduledTaskDefinition {
  const _ScheduledTaskDefinition({required this.name, required this.prompt, required this.projectId, required this.pluginId, required this.agent, required this.model, required this.variant, required this.fastMode, required this.dedicatedWorktree, required this.schedule, required this.timeZone, @JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) required this.missedRunPolicy, required this.runMode, @JsonKey(unknownEnumValue: TaskApprovalMode.unknown) required this.approvalMode});
  factory _ScheduledTaskDefinition.fromJson(Map<String, dynamic> json) => _$ScheduledTaskDefinitionFromJson(json);

/// Shown on the Scheduled page, run marks and pushes. Defaults to the
/// prompt's first line in the editor.
@override final  String name;
@override final  ScheduledTaskPrompt prompt;
@override final  String projectId;
@override final  String pluginId;
@override final  String? agent;
@override final  PromptModel? model;
@override final  SessionVariant? variant;
@override final  bool fastMode;
/// Whether each new-session run gets its own worktree. A same-session task
/// keeps the one its session started with.
@override final  bool dedicatedWorktree;
@override final  TaskSchedule schedule;
/// IANA zone name, such as `Europe/Bucharest`. Every [schedule] time is a
/// wall-clock time in this zone, whatever zone the bridge's computer uses.
@override final  String timeZone;
/// What happens when the bridge was off or asleep at a recurring run's
/// time. A one-off task always runs when the bridge is back.
@override@JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) final  TaskMissedRunPolicy missedRunPolicy;
@override final  TaskRunMode runMode;
@override@JsonKey(unknownEnumValue: TaskApprovalMode.unknown) final  TaskApprovalMode approvalMode;

/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskDefinitionCopyWith<_ScheduledTaskDefinition> get copyWith => __$ScheduledTaskDefinitionCopyWithImpl<_ScheduledTaskDefinition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskDefinitionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskDefinition&&(identical(other.name, name) || other.name == name)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.fastMode, fastMode) || other.fastMode == fastMode)&&(identical(other.dedicatedWorktree, dedicatedWorktree) || other.dedicatedWorktree == dedicatedWorktree)&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.missedRunPolicy, missedRunPolicy) || other.missedRunPolicy == missedRunPolicy)&&(identical(other.runMode, runMode) || other.runMode == runMode)&&(identical(other.approvalMode, approvalMode) || other.approvalMode == approvalMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,prompt,projectId,pluginId,agent,model,variant,fastMode,dedicatedWorktree,schedule,timeZone,missedRunPolicy,runMode,approvalMode);
}

@override
String toString() {
    return 'ScheduledTaskDefinition(name: $name, prompt: $prompt, projectId: $projectId, pluginId: $pluginId, agent: $agent, model: $model, variant: $variant, fastMode: $fastMode, dedicatedWorktree: $dedicatedWorktree, schedule: $schedule, timeZone: $timeZone, missedRunPolicy: $missedRunPolicy, runMode: $runMode, approvalMode: $approvalMode)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskDefinitionCopyWith<$Res> implements $ScheduledTaskDefinitionCopyWith<$Res> {
  factory _$ScheduledTaskDefinitionCopyWith(_ScheduledTaskDefinition value, $Res Function(_ScheduledTaskDefinition) _then) = __$ScheduledTaskDefinitionCopyWithImpl;
@override @useResult
$Res call({
 String name, ScheduledTaskPrompt prompt, String projectId, String pluginId, String? agent, PromptModel? model, SessionVariant? variant, bool fastMode, bool dedicatedWorktree, TaskSchedule schedule, String timeZone,@JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) TaskMissedRunPolicy missedRunPolicy, TaskRunMode runMode,@JsonKey(unknownEnumValue: TaskApprovalMode.unknown) TaskApprovalMode approvalMode
});


@override $PromptModelCopyWith<$Res>? get model;@override $SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class __$ScheduledTaskDefinitionCopyWithImpl<$Res>
    implements _$ScheduledTaskDefinitionCopyWith<$Res> {
  __$ScheduledTaskDefinitionCopyWithImpl(this._self, this._then);

  final _ScheduledTaskDefinition _self;
  final $Res Function(_ScheduledTaskDefinition) _then;

/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? prompt = null,Object? projectId = null,Object? pluginId = null,Object? agent = freezed,Object? model = freezed,Object? variant = freezed,Object? fastMode = null,Object? dedicatedWorktree = null,Object? schedule = null,Object? timeZone = null,Object? missedRunPolicy = null,Object? runMode = null,Object? approvalMode = null,}) {
  return _then(_ScheduledTaskDefinition(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as ScheduledTaskPrompt,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,fastMode: null == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as bool,dedicatedWorktree: null == dedicatedWorktree ? _self.dedicatedWorktree : dedicatedWorktree // ignore: cast_nullable_to_non_nullable
as bool,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as TaskSchedule,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,missedRunPolicy: null == missedRunPolicy ? _self.missedRunPolicy : missedRunPolicy // ignore: cast_nullable_to_non_nullable
as TaskMissedRunPolicy,runMode: null == runMode ? _self.runMode : runMode // ignore: cast_nullable_to_non_nullable
as TaskRunMode,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as TaskApprovalMode,
  ));
}

/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of ScheduledTaskDefinition
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res>? get variant {
    if (_self.variant == null) {
    return null;
  }

  return $SessionVariantCopyWith<$Res>(_self.variant!, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}

ScheduledTaskPrompt _$ScheduledTaskPromptFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'text':
          return ScheduledTaskPromptText.fromJson(
            json
          );
                case 'command':
          return ScheduledTaskPromptCommand.fromJson(
            json
          );
        
          default:
            return ScheduledTaskPromptUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$ScheduledTaskPrompt {



  /// Serializes this ScheduledTaskPrompt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskPrompt);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskPrompt()';
}


}





/// @nodoc
@JsonSerializable()

class ScheduledTaskPromptText implements ScheduledTaskPrompt {
  const ScheduledTaskPromptText({required this.text,  String? $type}): $type = $type ?? 'text';
  factory ScheduledTaskPromptText.fromJson(Map<String, dynamic> json) => _$ScheduledTaskPromptTextFromJson(json);

 final  String text;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskPromptTextToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskPromptText&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'ScheduledTaskPrompt.text(text: $text)';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskPromptCommand implements ScheduledTaskPrompt {
  const ScheduledTaskPromptCommand({required this.name, @JsonKey(unknownEnumValue: CommandSource.unknown) required this.source, required this.arguments,  String? $type}): $type = $type ?? 'command';
  factory ScheduledTaskPromptCommand.fromJson(Map<String, dynamic> json) => _$ScheduledTaskPromptCommandFromJson(json);

 final  String name;
@JsonKey(unknownEnumValue: CommandSource.unknown) final  CommandSource source;
 final  String? arguments;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskPromptCommandToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskPromptCommand&&(identical(other.name, name) || other.name == name)&&(identical(other.source, source) || other.source == source)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,source,arguments);
}

@override
String toString() {
    return 'ScheduledTaskPrompt.command(name: $name, source: $source, arguments: $arguments)';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskPromptUnknown implements ScheduledTaskPrompt {
  const ScheduledTaskPromptUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory ScheduledTaskPromptUnknown.fromJson(Map<String, dynamic> json) => _$ScheduledTaskPromptUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskPromptUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskPromptUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskPrompt.unknown()';
}


}




TaskSchedule _$TaskScheduleFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'once':
          return TaskScheduleOnce.fromJson(
            json
          );
                case 'daily':
          return TaskScheduleDaily.fromJson(
            json
          );
                case 'weekdays':
          return TaskScheduleWeekdays.fromJson(
            json
          );
                case 'weekly':
          return TaskScheduleWeekly.fromJson(
            json
          );
                case 'everyHours':
          return TaskScheduleEveryHours.fromJson(
            json
          );
        
          default:
            return TaskScheduleUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$TaskSchedule {



  /// Serializes this TaskSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskSchedule);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskSchedule()';
}


}





/// @nodoc
@JsonSerializable()

class TaskScheduleOnce implements TaskSchedule {
  const TaskScheduleOnce({required this.at,  String? $type}): $type = $type ?? 'once';
  factory TaskScheduleOnce.fromJson(Map<String, dynamic> json) => _$TaskScheduleOnceFromJson(json);

 final  TaskLocalDateTime at;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleOnceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleOnce&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,at);
}

@override
String toString() {
    return 'TaskSchedule.once(at: $at)';
}


}




/// @nodoc
@JsonSerializable()

class TaskScheduleDaily implements TaskSchedule {
  const TaskScheduleDaily({required this.time,  String? $type}): $type = $type ?? 'daily';
  factory TaskScheduleDaily.fromJson(Map<String, dynamic> json) => _$TaskScheduleDailyFromJson(json);

 final  TaskTimeOfDay time;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleDailyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleDaily&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,time);
}

@override
String toString() {
    return 'TaskSchedule.daily(time: $time)';
}


}




/// @nodoc
@JsonSerializable()

class TaskScheduleWeekdays implements TaskSchedule {
  const TaskScheduleWeekdays({required this.time,  String? $type}): $type = $type ?? 'weekdays';
  factory TaskScheduleWeekdays.fromJson(Map<String, dynamic> json) => _$TaskScheduleWeekdaysFromJson(json);

 final  TaskTimeOfDay time;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleWeekdaysToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleWeekdays&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,time);
}

@override
String toString() {
    return 'TaskSchedule.weekdays(time: $time)';
}


}




/// @nodoc
@JsonSerializable()

class TaskScheduleWeekly implements TaskSchedule {
  const TaskScheduleWeekly({required  Set<TaskWeekday> days, required this.time,  String? $type}): _days = days,$type = $type ?? 'weekly';
  factory TaskScheduleWeekly.fromJson(Map<String, dynamic> json) => _$TaskScheduleWeeklyFromJson(json);

 final  Set<TaskWeekday> _days;
 Set<TaskWeekday> get days {
  if (_days is EqualUnmodifiableSetView) return _days;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_days);
}

 final  TaskTimeOfDay time;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleWeeklyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleWeekly&&const DeepCollectionEquality().equals(other.days, _days)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_days),time);
}

@override
String toString() {
    return 'TaskSchedule.weekly(days: $days, time: $time)';
}


}




/// @nodoc
@JsonSerializable()

class TaskScheduleEveryHours implements TaskSchedule {
  const TaskScheduleEveryHours({required this.hours, required this.start,  String? $type}): $type = $type ?? 'everyHours';
  factory TaskScheduleEveryHours.fromJson(Map<String, dynamic> json) => _$TaskScheduleEveryHoursFromJson(json);

 final  int hours;
 final  TaskLocalDateTime start;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleEveryHoursToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleEveryHours&&(identical(other.hours, hours) || other.hours == hours)&&(identical(other.start, start) || other.start == start));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hours,start);
}

@override
String toString() {
    return 'TaskSchedule.everyHours(hours: $hours, start: $start)';
}


}




/// @nodoc
@JsonSerializable()

class TaskScheduleUnknown implements TaskSchedule {
  const TaskScheduleUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory TaskScheduleUnknown.fromJson(Map<String, dynamic> json) => _$TaskScheduleUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskScheduleUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskScheduleUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskSchedule.unknown()';
}


}





/// @nodoc
mixin _$TaskTimeOfDay {

 int get hour; int get minute;
/// Create a copy of TaskTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskTimeOfDayCopyWith<TaskTimeOfDay> get copyWith => _$TaskTimeOfDayCopyWithImpl<TaskTimeOfDay>(this as TaskTimeOfDay, _$identity);

  /// Serializes this TaskTimeOfDay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskTimeOfDay;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskTimeOfDay&&(identical(other.hour, _this.hour) || other.hour == _this.hour)&&(identical(other.minute, _this.minute) || other.minute == _this.minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskTimeOfDay;
  return Object.hash(runtimeType,_this.hour,_this.minute);
}

@override
String toString() {
  final _this = this as TaskTimeOfDay;
  return 'TaskTimeOfDay(hour: ${_this.hour}, minute: ${_this.minute})';
}


}

/// @nodoc
abstract mixin class $TaskTimeOfDayCopyWith<$Res>  {
  factory $TaskTimeOfDayCopyWith(TaskTimeOfDay value, $Res Function(TaskTimeOfDay) _then) = _$TaskTimeOfDayCopyWithImpl;
@useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class _$TaskTimeOfDayCopyWithImpl<$Res>
    implements $TaskTimeOfDayCopyWith<$Res> {
  _$TaskTimeOfDayCopyWithImpl(this._self, this._then);

  final TaskTimeOfDay _self;
  final $Res Function(TaskTimeOfDay) _then;

/// Create a copy of TaskTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(TaskTimeOfDay(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _TaskTimeOfDay implements TaskTimeOfDay {
  const _TaskTimeOfDay({required this.hour, required this.minute});
  factory _TaskTimeOfDay.fromJson(Map<String, dynamic> json) => _$TaskTimeOfDayFromJson(json);

@override final  int hour;
@override final  int minute;

/// Create a copy of TaskTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskTimeOfDayCopyWith<_TaskTimeOfDay> get copyWith => __$TaskTimeOfDayCopyWithImpl<_TaskTimeOfDay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskTimeOfDayToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskTimeOfDay&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hour,minute);
}

@override
String toString() {
    return 'TaskTimeOfDay(hour: $hour, minute: $minute)';
}


}

/// @nodoc
abstract mixin class _$TaskTimeOfDayCopyWith<$Res> implements $TaskTimeOfDayCopyWith<$Res> {
  factory _$TaskTimeOfDayCopyWith(_TaskTimeOfDay value, $Res Function(_TaskTimeOfDay) _then) = __$TaskTimeOfDayCopyWithImpl;
@override @useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class __$TaskTimeOfDayCopyWithImpl<$Res>
    implements _$TaskTimeOfDayCopyWith<$Res> {
  __$TaskTimeOfDayCopyWithImpl(this._self, this._then);

  final _TaskTimeOfDay _self;
  final $Res Function(_TaskTimeOfDay) _then;

/// Create a copy of TaskTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(_TaskTimeOfDay(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TaskLocalDateTime {

 int get year; int get month; int get day; int get hour; int get minute;
/// Create a copy of TaskLocalDateTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskLocalDateTimeCopyWith<TaskLocalDateTime> get copyWith => _$TaskLocalDateTimeCopyWithImpl<TaskLocalDateTime>(this as TaskLocalDateTime, _$identity);

  /// Serializes this TaskLocalDateTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskLocalDateTime;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskLocalDateTime&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.month, _this.month) || other.month == _this.month)&&(identical(other.day, _this.day) || other.day == _this.day)&&(identical(other.hour, _this.hour) || other.hour == _this.hour)&&(identical(other.minute, _this.minute) || other.minute == _this.minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskLocalDateTime;
  return Object.hash(runtimeType,_this.year,_this.month,_this.day,_this.hour,_this.minute);
}

@override
String toString() {
  final _this = this as TaskLocalDateTime;
  return 'TaskLocalDateTime(year: ${_this.year}, month: ${_this.month}, day: ${_this.day}, hour: ${_this.hour}, minute: ${_this.minute})';
}


}

/// @nodoc
abstract mixin class $TaskLocalDateTimeCopyWith<$Res>  {
  factory $TaskLocalDateTimeCopyWith(TaskLocalDateTime value, $Res Function(TaskLocalDateTime) _then) = _$TaskLocalDateTimeCopyWithImpl;
@useResult
$Res call({
 int year, int month, int day, int hour, int minute
});




}
/// @nodoc
class _$TaskLocalDateTimeCopyWithImpl<$Res>
    implements $TaskLocalDateTimeCopyWith<$Res> {
  _$TaskLocalDateTimeCopyWithImpl(this._self, this._then);

  final TaskLocalDateTime _self;
  final $Res Function(TaskLocalDateTime) _then;

/// Create a copy of TaskLocalDateTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? month = null,Object? day = null,Object? hour = null,Object? minute = null,}) {
  return _then(TaskLocalDateTime(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _TaskLocalDateTime implements TaskLocalDateTime {
  const _TaskLocalDateTime({required this.year, required this.month, required this.day, required this.hour, required this.minute});
  factory _TaskLocalDateTime.fromJson(Map<String, dynamic> json) => _$TaskLocalDateTimeFromJson(json);

@override final  int year;
@override final  int month;
@override final  int day;
@override final  int hour;
@override final  int minute;

/// Create a copy of TaskLocalDateTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskLocalDateTimeCopyWith<_TaskLocalDateTime> get copyWith => __$TaskLocalDateTimeCopyWithImpl<_TaskLocalDateTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskLocalDateTimeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskLocalDateTime&&(identical(other.year, year) || other.year == year)&&(identical(other.month, month) || other.month == month)&&(identical(other.day, day) || other.day == day)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,year,month,day,hour,minute);
}

@override
String toString() {
    return 'TaskLocalDateTime(year: $year, month: $month, day: $day, hour: $hour, minute: $minute)';
}


}

/// @nodoc
abstract mixin class _$TaskLocalDateTimeCopyWith<$Res> implements $TaskLocalDateTimeCopyWith<$Res> {
  factory _$TaskLocalDateTimeCopyWith(_TaskLocalDateTime value, $Res Function(_TaskLocalDateTime) _then) = __$TaskLocalDateTimeCopyWithImpl;
@override @useResult
$Res call({
 int year, int month, int day, int hour, int minute
});




}
/// @nodoc
class __$TaskLocalDateTimeCopyWithImpl<$Res>
    implements _$TaskLocalDateTimeCopyWith<$Res> {
  __$TaskLocalDateTimeCopyWithImpl(this._self, this._then);

  final _TaskLocalDateTime _self;
  final $Res Function(_TaskLocalDateTime) _then;

/// Create a copy of TaskLocalDateTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? month = null,Object? day = null,Object? hour = null,Object? minute = null,}) {
  return _then(_TaskLocalDateTime(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

TaskRunMode _$TaskRunModeFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'newSession':
          return TaskRunModeNewSession.fromJson(
            json
          );
                case 'sameSession':
          return TaskRunModeSameSession.fromJson(
            json
          );
        
          default:
            return TaskRunModeUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$TaskRunMode {



  /// Serializes this TaskRunMode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskRunMode);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskRunMode()';
}


}





/// @nodoc
@JsonSerializable()

class TaskRunModeNewSession implements TaskRunMode {
  const TaskRunModeNewSession({ String? $type}): $type = $type ?? 'newSession';
  factory TaskRunModeNewSession.fromJson(Map<String, dynamic> json) => _$TaskRunModeNewSessionFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskRunModeNewSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskRunModeNewSession);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskRunMode.newSession()';
}


}




/// @nodoc
@JsonSerializable()

class TaskRunModeSameSession implements TaskRunMode {
  const TaskRunModeSameSession({required this.autoCompact,  String? $type}): $type = $type ?? 'sameSession';
  factory TaskRunModeSameSession.fromJson(Map<String, dynamic> json) => _$TaskRunModeSameSessionFromJson(json);

 final  bool autoCompact;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskRunModeSameSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskRunModeSameSession&&(identical(other.autoCompact, autoCompact) || other.autoCompact == autoCompact));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,autoCompact);
}

@override
String toString() {
    return 'TaskRunMode.sameSession(autoCompact: $autoCompact)';
}


}




/// @nodoc
@JsonSerializable()

class TaskRunModeUnknown implements TaskRunMode {
  const TaskRunModeUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory TaskRunModeUnknown.fromJson(Map<String, dynamic> json) => _$TaskRunModeUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$TaskRunModeUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskRunModeUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TaskRunMode.unknown()';
}


}





/// @nodoc
mixin _$ScheduledTaskInstant {

/// UTC Unix milliseconds.
 int get at;/// The task zone's UTC offset at [at], in minutes east of UTC.
 int get offsetMinutes;
/// Create a copy of ScheduledTaskInstant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskInstantCopyWith<ScheduledTaskInstant> get copyWith => _$ScheduledTaskInstantCopyWithImpl<ScheduledTaskInstant>(this as ScheduledTaskInstant, _$identity);

  /// Serializes this ScheduledTaskInstant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskInstant;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskInstant&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.offsetMinutes, _this.offsetMinutes) || other.offsetMinutes == _this.offsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskInstant;
  return Object.hash(runtimeType,_this.at,_this.offsetMinutes);
}

@override
String toString() {
  final _this = this as ScheduledTaskInstant;
  return 'ScheduledTaskInstant(at: ${_this.at}, offsetMinutes: ${_this.offsetMinutes})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskInstantCopyWith<$Res>  {
  factory $ScheduledTaskInstantCopyWith(ScheduledTaskInstant value, $Res Function(ScheduledTaskInstant) _then) = _$ScheduledTaskInstantCopyWithImpl;
@useResult
$Res call({
 int at, int offsetMinutes
});




}
/// @nodoc
class _$ScheduledTaskInstantCopyWithImpl<$Res>
    implements $ScheduledTaskInstantCopyWith<$Res> {
  _$ScheduledTaskInstantCopyWithImpl(this._self, this._then);

  final ScheduledTaskInstant _self;
  final $Res Function(ScheduledTaskInstant) _then;

/// Create a copy of ScheduledTaskInstant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? offsetMinutes = null,}) {
  return _then(ScheduledTaskInstant(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as int,offsetMinutes: null == offsetMinutes ? _self.offsetMinutes : offsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskInstant implements ScheduledTaskInstant {
  const _ScheduledTaskInstant({required this.at, required this.offsetMinutes});
  factory _ScheduledTaskInstant.fromJson(Map<String, dynamic> json) => _$ScheduledTaskInstantFromJson(json);

/// UTC Unix milliseconds.
@override final  int at;
/// The task zone's UTC offset at [at], in minutes east of UTC.
@override final  int offsetMinutes;

/// Create a copy of ScheduledTaskInstant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskInstantCopyWith<_ScheduledTaskInstant> get copyWith => __$ScheduledTaskInstantCopyWithImpl<_ScheduledTaskInstant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskInstantToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskInstant&&(identical(other.at, at) || other.at == at)&&(identical(other.offsetMinutes, offsetMinutes) || other.offsetMinutes == offsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,at,offsetMinutes);
}

@override
String toString() {
    return 'ScheduledTaskInstant(at: $at, offsetMinutes: $offsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskInstantCopyWith<$Res> implements $ScheduledTaskInstantCopyWith<$Res> {
  factory _$ScheduledTaskInstantCopyWith(_ScheduledTaskInstant value, $Res Function(_ScheduledTaskInstant) _then) = __$ScheduledTaskInstantCopyWithImpl;
@override @useResult
$Res call({
 int at, int offsetMinutes
});




}
/// @nodoc
class __$ScheduledTaskInstantCopyWithImpl<$Res>
    implements _$ScheduledTaskInstantCopyWith<$Res> {
  __$ScheduledTaskInstantCopyWithImpl(this._self, this._then);

  final _ScheduledTaskInstant _self;
  final $Res Function(_ScheduledTaskInstant) _then;

/// Create a copy of ScheduledTaskInstant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? offsetMinutes = null,}) {
  return _then(_ScheduledTaskInstant(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as int,offsetMinutes: null == offsetMinutes ? _self.offsetMinutes : offsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ScheduledTaskRun {

 String get id;/// The occurrence this run was for, or when Run now was tapped. Its offset
/// is frozen when the row is written, so a later zone edit keeps past rows.
 ScheduledTaskInstant get scheduledFor; ScheduledTaskRunOutcome get outcome;
/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskRunCopyWith<ScheduledTaskRun> get copyWith => _$ScheduledTaskRunCopyWithImpl<ScheduledTaskRun>(this as ScheduledTaskRun, _$identity);

  /// Serializes this ScheduledTaskRun to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskRun;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRun&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.scheduledFor, _this.scheduledFor) || other.scheduledFor == _this.scheduledFor)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskRun;
  return Object.hash(runtimeType,_this.id,_this.scheduledFor,_this.outcome);
}

@override
String toString() {
  final _this = this as ScheduledTaskRun;
  return 'ScheduledTaskRun(id: ${_this.id}, scheduledFor: ${_this.scheduledFor}, outcome: ${_this.outcome})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskRunCopyWith<$Res>  {
  factory $ScheduledTaskRunCopyWith(ScheduledTaskRun value, $Res Function(ScheduledTaskRun) _then) = _$ScheduledTaskRunCopyWithImpl;
@useResult
$Res call({
 String id, ScheduledTaskInstant scheduledFor, ScheduledTaskRunOutcome outcome
});


$ScheduledTaskInstantCopyWith<$Res> get scheduledFor;

}
/// @nodoc
class _$ScheduledTaskRunCopyWithImpl<$Res>
    implements $ScheduledTaskRunCopyWith<$Res> {
  _$ScheduledTaskRunCopyWithImpl(this._self, this._then);

  final ScheduledTaskRun _self;
  final $Res Function(ScheduledTaskRun) _then;

/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scheduledFor = null,Object? outcome = null,}) {
  return _then(ScheduledTaskRun(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as ScheduledTaskInstant,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRunOutcome,
  ));
}
/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskInstantCopyWith<$Res> get scheduledFor {
  
  return $ScheduledTaskInstantCopyWith<$Res>(_self.scheduledFor, (value) {
    return _then(_self.copyWith(scheduledFor: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskRun implements ScheduledTaskRun {
  const _ScheduledTaskRun({required this.id, required this.scheduledFor, required this.outcome});
  factory _ScheduledTaskRun.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunFromJson(json);

@override final  String id;
/// The occurrence this run was for, or when Run now was tapped. Its offset
/// is frozen when the row is written, so a later zone edit keeps past rows.
@override final  ScheduledTaskInstant scheduledFor;
@override final  ScheduledTaskRunOutcome outcome;

/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskRunCopyWith<_ScheduledTaskRun> get copyWith => __$ScheduledTaskRunCopyWithImpl<_ScheduledTaskRun>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskRun&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,scheduledFor,outcome);
}

@override
String toString() {
    return 'ScheduledTaskRun(id: $id, scheduledFor: $scheduledFor, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskRunCopyWith<$Res> implements $ScheduledTaskRunCopyWith<$Res> {
  factory _$ScheduledTaskRunCopyWith(_ScheduledTaskRun value, $Res Function(_ScheduledTaskRun) _then) = __$ScheduledTaskRunCopyWithImpl;
@override @useResult
$Res call({
 String id, ScheduledTaskInstant scheduledFor, ScheduledTaskRunOutcome outcome
});


@override $ScheduledTaskInstantCopyWith<$Res> get scheduledFor;

}
/// @nodoc
class __$ScheduledTaskRunCopyWithImpl<$Res>
    implements _$ScheduledTaskRunCopyWith<$Res> {
  __$ScheduledTaskRunCopyWithImpl(this._self, this._then);

  final _ScheduledTaskRun _self;
  final $Res Function(_ScheduledTaskRun) _then;

/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scheduledFor = null,Object? outcome = null,}) {
  return _then(_ScheduledTaskRun(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as ScheduledTaskInstant,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRunOutcome,
  ));
}

/// Create a copy of ScheduledTaskRun
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskInstantCopyWith<$Res> get scheduledFor {
  
  return $ScheduledTaskInstantCopyWith<$Res>(_self.scheduledFor, (value) {
    return _then(_self.copyWith(scheduledFor: value));
  });
}
}

ScheduledTaskRunOutcome _$ScheduledTaskRunOutcomeFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'started':
          return ScheduledTaskRunStarted.fromJson(
            json
          );
                case 'skipped':
          return ScheduledTaskRunSkipped.fromJson(
            json
          );
                case 'missed':
          return ScheduledTaskRunMissed.fromJson(
            json
          );
                case 'failed':
          return ScheduledTaskRunFailed.fromJson(
            json
          );
        
          default:
            return ScheduledTaskRunOutcomeUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$ScheduledTaskRunOutcome {



  /// Serializes this ScheduledTaskRunOutcome to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunOutcome);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskRunOutcome()';
}


}





/// @nodoc
@JsonSerializable()

class ScheduledTaskRunStarted implements ScheduledTaskRunOutcome {
  const ScheduledTaskRunStarted({required this.sessionId, required this.late,  String? $type}): $type = $type ?? 'started';
  factory ScheduledTaskRunStarted.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunStartedFromJson(json);

 final  String? sessionId;
 final  bool late;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunStartedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunStarted&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.late, late) || other.late == late));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,late);
}

@override
String toString() {
    return 'ScheduledTaskRunOutcome.started(sessionId: $sessionId, late: $late)';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskRunSkipped implements ScheduledTaskRunOutcome {
  const ScheduledTaskRunSkipped({ String? $type}): $type = $type ?? 'skipped';
  factory ScheduledTaskRunSkipped.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunSkippedFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunSkippedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunSkipped);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskRunOutcome.skipped()';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskRunMissed implements ScheduledTaskRunOutcome {
  const ScheduledTaskRunMissed({ String? $type}): $type = $type ?? 'missed';
  factory ScheduledTaskRunMissed.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunMissedFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunMissedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunMissed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskRunOutcome.missed()';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskRunFailed implements ScheduledTaskRunOutcome {
  const ScheduledTaskRunFailed({@JsonKey(unknownEnumValue: TaskRunFailureReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'failed';
  factory ScheduledTaskRunFailed.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunFailedFromJson(json);

@JsonKey(unknownEnumValue: TaskRunFailureReason.unknown) final  TaskRunFailureReason reason;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunFailed&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'ScheduledTaskRunOutcome.failed(reason: $reason)';
}


}




/// @nodoc
@JsonSerializable()

class ScheduledTaskRunOutcomeUnknown implements ScheduledTaskRunOutcome {
  const ScheduledTaskRunOutcomeUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory ScheduledTaskRunOutcomeUnknown.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunOutcomeUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunOutcomeUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunOutcomeUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ScheduledTaskRunOutcome.unknown()';
}


}





/// @nodoc
mixin _$SessionScheduledTaskMark {

 String get taskId; String get name;@JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) ScheduledTaskKind get kind;
/// Create a copy of SessionScheduledTaskMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionScheduledTaskMarkCopyWith<SessionScheduledTaskMark> get copyWith => _$SessionScheduledTaskMarkCopyWithImpl<SessionScheduledTaskMark>(this as SessionScheduledTaskMark, _$identity);

  /// Serializes this SessionScheduledTaskMark to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionScheduledTaskMark;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionScheduledTaskMark&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionScheduledTaskMark;
  return Object.hash(runtimeType,_this.taskId,_this.name,_this.kind);
}

@override
String toString() {
  final _this = this as SessionScheduledTaskMark;
  return 'SessionScheduledTaskMark(taskId: ${_this.taskId}, name: ${_this.name}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $SessionScheduledTaskMarkCopyWith<$Res>  {
  factory $SessionScheduledTaskMarkCopyWith(SessionScheduledTaskMark value, $Res Function(SessionScheduledTaskMark) _then) = _$SessionScheduledTaskMarkCopyWithImpl;
@useResult
$Res call({
 String taskId, String name,@JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) ScheduledTaskKind kind
});




}
/// @nodoc
class _$SessionScheduledTaskMarkCopyWithImpl<$Res>
    implements $SessionScheduledTaskMarkCopyWith<$Res> {
  _$SessionScheduledTaskMarkCopyWithImpl(this._self, this._then);

  final SessionScheduledTaskMark _self;
  final $Res Function(SessionScheduledTaskMark) _then;

/// Create a copy of SessionScheduledTaskMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskId = null,Object? name = null,Object? kind = null,}) {
  return _then(SessionScheduledTaskMark(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ScheduledTaskKind,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionScheduledTaskMark implements SessionScheduledTaskMark {
  const _SessionScheduledTaskMark({required this.taskId, required this.name, @JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) required this.kind});
  factory _SessionScheduledTaskMark.fromJson(Map<String, dynamic> json) => _$SessionScheduledTaskMarkFromJson(json);

@override final  String taskId;
@override final  String name;
@override@JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) final  ScheduledTaskKind kind;

/// Create a copy of SessionScheduledTaskMark
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionScheduledTaskMarkCopyWith<_SessionScheduledTaskMark> get copyWith => __$SessionScheduledTaskMarkCopyWithImpl<_SessionScheduledTaskMark>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionScheduledTaskMarkToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionScheduledTaskMark&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,taskId,name,kind);
}

@override
String toString() {
    return 'SessionScheduledTaskMark(taskId: $taskId, name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$SessionScheduledTaskMarkCopyWith<$Res> implements $SessionScheduledTaskMarkCopyWith<$Res> {
  factory _$SessionScheduledTaskMarkCopyWith(_SessionScheduledTaskMark value, $Res Function(_SessionScheduledTaskMark) _then) = __$SessionScheduledTaskMarkCopyWithImpl;
@override @useResult
$Res call({
 String taskId, String name,@JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) ScheduledTaskKind kind
});




}
/// @nodoc
class __$SessionScheduledTaskMarkCopyWithImpl<$Res>
    implements _$SessionScheduledTaskMarkCopyWith<$Res> {
  __$SessionScheduledTaskMarkCopyWithImpl(this._self, this._then);

  final _SessionScheduledTaskMark _self;
  final $Res Function(_SessionScheduledTaskMark) _then;

/// Create a copy of SessionScheduledTaskMark
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskId = null,Object? name = null,Object? kind = null,}) {
  return _then(_SessionScheduledTaskMark(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ScheduledTaskKind,
  ));
}


}

// dart format on
