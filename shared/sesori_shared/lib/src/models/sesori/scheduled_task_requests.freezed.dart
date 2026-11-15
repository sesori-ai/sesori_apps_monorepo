// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_task_requests.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduledTaskListResponse {

 List<ScheduledTask> get items;
/// Create a copy of ScheduledTaskListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskListResponseCopyWith<ScheduledTaskListResponse> get copyWith => _$ScheduledTaskListResponseCopyWithImpl<ScheduledTaskListResponse>(this as ScheduledTaskListResponse, _$identity);

  /// Serializes this ScheduledTaskListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskListResponse&&const DeepCollectionEquality().equals(other.items, _this.items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as ScheduledTaskListResponse;
  return 'ScheduledTaskListResponse(items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskListResponseCopyWith<$Res>  {
  factory $ScheduledTaskListResponseCopyWith(ScheduledTaskListResponse value, $Res Function(ScheduledTaskListResponse) _then) = _$ScheduledTaskListResponseCopyWithImpl;
@useResult
$Res call({
 List<ScheduledTask> items
});




}
/// @nodoc
class _$ScheduledTaskListResponseCopyWithImpl<$Res>
    implements $ScheduledTaskListResponseCopyWith<$Res> {
  _$ScheduledTaskListResponseCopyWithImpl(this._self, this._then);

  final ScheduledTaskListResponse _self;
  final $Res Function(ScheduledTaskListResponse) _then;

/// Create a copy of ScheduledTaskListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(ScheduledTaskListResponse(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ScheduledTask>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskListResponse implements ScheduledTaskListResponse {
  const _ScheduledTaskListResponse({required  List<ScheduledTask> items}): _items = items;
  factory _ScheduledTaskListResponse.fromJson(Map<String, dynamic> json) => _$ScheduledTaskListResponseFromJson(json);

 final  List<ScheduledTask> _items;
@override List<ScheduledTask> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ScheduledTaskListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskListResponseCopyWith<_ScheduledTaskListResponse> get copyWith => __$ScheduledTaskListResponseCopyWithImpl<_ScheduledTaskListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskListResponse&&const DeepCollectionEquality().equals(other.items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'ScheduledTaskListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskListResponseCopyWith<$Res> implements $ScheduledTaskListResponseCopyWith<$Res> {
  factory _$ScheduledTaskListResponseCopyWith(_ScheduledTaskListResponse value, $Res Function(_ScheduledTaskListResponse) _then) = __$ScheduledTaskListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<ScheduledTask> items
});




}
/// @nodoc
class __$ScheduledTaskListResponseCopyWithImpl<$Res>
    implements _$ScheduledTaskListResponseCopyWith<$Res> {
  __$ScheduledTaskListResponseCopyWithImpl(this._self, this._then);

  final _ScheduledTaskListResponse _self;
  final $Res Function(_ScheduledTaskListResponse) _then;

/// Create a copy of ScheduledTaskListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_ScheduledTaskListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ScheduledTask>,
  ));
}


}


/// @nodoc
mixin _$CreateScheduledTaskRequest {

 ScheduledTaskDefinition get definition;
/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateScheduledTaskRequestCopyWith<CreateScheduledTaskRequest> get copyWith => _$CreateScheduledTaskRequestCopyWithImpl<CreateScheduledTaskRequest>(this as CreateScheduledTaskRequest, _$identity);

  /// Serializes this CreateScheduledTaskRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CreateScheduledTaskRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateScheduledTaskRequest&&(identical(other.definition, _this.definition) || other.definition == _this.definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CreateScheduledTaskRequest;
  return Object.hash(runtimeType,_this.definition);
}

@override
String toString() {
  final _this = this as CreateScheduledTaskRequest;
  return 'CreateScheduledTaskRequest(definition: ${_this.definition})';
}


}

/// @nodoc
abstract mixin class $CreateScheduledTaskRequestCopyWith<$Res>  {
  factory $CreateScheduledTaskRequestCopyWith(CreateScheduledTaskRequest value, $Res Function(CreateScheduledTaskRequest) _then) = _$CreateScheduledTaskRequestCopyWithImpl;
@useResult
$Res call({
 ScheduledTaskDefinition definition
});


$ScheduledTaskDefinitionCopyWith<$Res> get definition;

}
/// @nodoc
class _$CreateScheduledTaskRequestCopyWithImpl<$Res>
    implements $CreateScheduledTaskRequestCopyWith<$Res> {
  _$CreateScheduledTaskRequestCopyWithImpl(this._self, this._then);

  final CreateScheduledTaskRequest _self;
  final $Res Function(CreateScheduledTaskRequest) _then;

/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? definition = null,}) {
  return _then(CreateScheduledTaskRequest(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,
  ));
}
/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CreateScheduledTaskRequest implements CreateScheduledTaskRequest {
  const _CreateScheduledTaskRequest({required this.definition});
  factory _CreateScheduledTaskRequest.fromJson(Map<String, dynamic> json) => _$CreateScheduledTaskRequestFromJson(json);

@override final  ScheduledTaskDefinition definition;

/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateScheduledTaskRequestCopyWith<_CreateScheduledTaskRequest> get copyWith => __$CreateScheduledTaskRequestCopyWithImpl<_CreateScheduledTaskRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateScheduledTaskRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateScheduledTaskRequest&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,definition);
}

@override
String toString() {
    return 'CreateScheduledTaskRequest(definition: $definition)';
}


}

/// @nodoc
abstract mixin class _$CreateScheduledTaskRequestCopyWith<$Res> implements $CreateScheduledTaskRequestCopyWith<$Res> {
  factory _$CreateScheduledTaskRequestCopyWith(_CreateScheduledTaskRequest value, $Res Function(_CreateScheduledTaskRequest) _then) = __$CreateScheduledTaskRequestCopyWithImpl;
@override @useResult
$Res call({
 ScheduledTaskDefinition definition
});


@override $ScheduledTaskDefinitionCopyWith<$Res> get definition;

}
/// @nodoc
class __$CreateScheduledTaskRequestCopyWithImpl<$Res>
    implements _$CreateScheduledTaskRequestCopyWith<$Res> {
  __$CreateScheduledTaskRequestCopyWithImpl(this._self, this._then);

  final _CreateScheduledTaskRequest _self;
  final $Res Function(_CreateScheduledTaskRequest) _then;

/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? definition = null,}) {
  return _then(_CreateScheduledTaskRequest(
definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,
  ));
}

/// Create a copy of CreateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// @nodoc
mixin _$UpdateScheduledTaskRequest {

 String get taskId; ScheduledTaskDefinition get definition;
/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateScheduledTaskRequestCopyWith<UpdateScheduledTaskRequest> get copyWith => _$UpdateScheduledTaskRequestCopyWithImpl<UpdateScheduledTaskRequest>(this as UpdateScheduledTaskRequest, _$identity);

  /// Serializes this UpdateScheduledTaskRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UpdateScheduledTaskRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateScheduledTaskRequest&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId)&&(identical(other.definition, _this.definition) || other.definition == _this.definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UpdateScheduledTaskRequest;
  return Object.hash(runtimeType,_this.taskId,_this.definition);
}

@override
String toString() {
  final _this = this as UpdateScheduledTaskRequest;
  return 'UpdateScheduledTaskRequest(taskId: ${_this.taskId}, definition: ${_this.definition})';
}


}

/// @nodoc
abstract mixin class $UpdateScheduledTaskRequestCopyWith<$Res>  {
  factory $UpdateScheduledTaskRequestCopyWith(UpdateScheduledTaskRequest value, $Res Function(UpdateScheduledTaskRequest) _then) = _$UpdateScheduledTaskRequestCopyWithImpl;
@useResult
$Res call({
 String taskId, ScheduledTaskDefinition definition
});


$ScheduledTaskDefinitionCopyWith<$Res> get definition;

}
/// @nodoc
class _$UpdateScheduledTaskRequestCopyWithImpl<$Res>
    implements $UpdateScheduledTaskRequestCopyWith<$Res> {
  _$UpdateScheduledTaskRequestCopyWithImpl(this._self, this._then);

  final UpdateScheduledTaskRequest _self;
  final $Res Function(UpdateScheduledTaskRequest) _then;

/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskId = null,Object? definition = null,}) {
  return _then(UpdateScheduledTaskRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,
  ));
}
/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _UpdateScheduledTaskRequest implements UpdateScheduledTaskRequest {
  const _UpdateScheduledTaskRequest({required this.taskId, required this.definition});
  factory _UpdateScheduledTaskRequest.fromJson(Map<String, dynamic> json) => _$UpdateScheduledTaskRequestFromJson(json);

@override final  String taskId;
@override final  ScheduledTaskDefinition definition;

/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateScheduledTaskRequestCopyWith<_UpdateScheduledTaskRequest> get copyWith => __$UpdateScheduledTaskRequestCopyWithImpl<_UpdateScheduledTaskRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateScheduledTaskRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateScheduledTaskRequest&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.definition, definition) || other.definition == definition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,taskId,definition);
}

@override
String toString() {
    return 'UpdateScheduledTaskRequest(taskId: $taskId, definition: $definition)';
}


}

/// @nodoc
abstract mixin class _$UpdateScheduledTaskRequestCopyWith<$Res> implements $UpdateScheduledTaskRequestCopyWith<$Res> {
  factory _$UpdateScheduledTaskRequestCopyWith(_UpdateScheduledTaskRequest value, $Res Function(_UpdateScheduledTaskRequest) _then) = __$UpdateScheduledTaskRequestCopyWithImpl;
@override @useResult
$Res call({
 String taskId, ScheduledTaskDefinition definition
});


@override $ScheduledTaskDefinitionCopyWith<$Res> get definition;

}
/// @nodoc
class __$UpdateScheduledTaskRequestCopyWithImpl<$Res>
    implements _$UpdateScheduledTaskRequestCopyWith<$Res> {
  __$UpdateScheduledTaskRequestCopyWithImpl(this._self, this._then);

  final _UpdateScheduledTaskRequest _self;
  final $Res Function(_UpdateScheduledTaskRequest) _then;

/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskId = null,Object? definition = null,}) {
  return _then(_UpdateScheduledTaskRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as ScheduledTaskDefinition,
  ));
}

/// Create a copy of UpdateScheduledTaskRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskDefinitionCopyWith<$Res> get definition {
  
  return $ScheduledTaskDefinitionCopyWith<$Res>(_self.definition, (value) {
    return _then(_self.copyWith(definition: value));
  });
}
}


/// @nodoc
mixin _$SetScheduledTaskEnabledRequest {

 String get taskId; bool get enabled;
/// Create a copy of SetScheduledTaskEnabledRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetScheduledTaskEnabledRequestCopyWith<SetScheduledTaskEnabledRequest> get copyWith => _$SetScheduledTaskEnabledRequestCopyWithImpl<SetScheduledTaskEnabledRequest>(this as SetScheduledTaskEnabledRequest, _$identity);

  /// Serializes this SetScheduledTaskEnabledRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SetScheduledTaskEnabledRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetScheduledTaskEnabledRequest&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SetScheduledTaskEnabledRequest;
  return Object.hash(runtimeType,_this.taskId,_this.enabled);
}

@override
String toString() {
  final _this = this as SetScheduledTaskEnabledRequest;
  return 'SetScheduledTaskEnabledRequest(taskId: ${_this.taskId}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $SetScheduledTaskEnabledRequestCopyWith<$Res>  {
  factory $SetScheduledTaskEnabledRequestCopyWith(SetScheduledTaskEnabledRequest value, $Res Function(SetScheduledTaskEnabledRequest) _then) = _$SetScheduledTaskEnabledRequestCopyWithImpl;
@useResult
$Res call({
 String taskId, bool enabled
});




}
/// @nodoc
class _$SetScheduledTaskEnabledRequestCopyWithImpl<$Res>
    implements $SetScheduledTaskEnabledRequestCopyWith<$Res> {
  _$SetScheduledTaskEnabledRequestCopyWithImpl(this._self, this._then);

  final SetScheduledTaskEnabledRequest _self;
  final $Res Function(SetScheduledTaskEnabledRequest) _then;

/// Create a copy of SetScheduledTaskEnabledRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskId = null,Object? enabled = null,}) {
  return _then(SetScheduledTaskEnabledRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetScheduledTaskEnabledRequest implements SetScheduledTaskEnabledRequest {
  const _SetScheduledTaskEnabledRequest({required this.taskId, required this.enabled});
  factory _SetScheduledTaskEnabledRequest.fromJson(Map<String, dynamic> json) => _$SetScheduledTaskEnabledRequestFromJson(json);

@override final  String taskId;
@override final  bool enabled;

/// Create a copy of SetScheduledTaskEnabledRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetScheduledTaskEnabledRequestCopyWith<_SetScheduledTaskEnabledRequest> get copyWith => __$SetScheduledTaskEnabledRequestCopyWithImpl<_SetScheduledTaskEnabledRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetScheduledTaskEnabledRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetScheduledTaskEnabledRequest&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,taskId,enabled);
}

@override
String toString() {
    return 'SetScheduledTaskEnabledRequest(taskId: $taskId, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$SetScheduledTaskEnabledRequestCopyWith<$Res> implements $SetScheduledTaskEnabledRequestCopyWith<$Res> {
  factory _$SetScheduledTaskEnabledRequestCopyWith(_SetScheduledTaskEnabledRequest value, $Res Function(_SetScheduledTaskEnabledRequest) _then) = __$SetScheduledTaskEnabledRequestCopyWithImpl;
@override @useResult
$Res call({
 String taskId, bool enabled
});




}
/// @nodoc
class __$SetScheduledTaskEnabledRequestCopyWithImpl<$Res>
    implements _$SetScheduledTaskEnabledRequestCopyWith<$Res> {
  __$SetScheduledTaskEnabledRequestCopyWithImpl(this._self, this._then);

  final _SetScheduledTaskEnabledRequest _self;
  final $Res Function(_SetScheduledTaskEnabledRequest) _then;

/// Create a copy of SetScheduledTaskEnabledRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskId = null,Object? enabled = null,}) {
  return _then(_SetScheduledTaskEnabledRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ScheduledTaskIdRequest {

 String get taskId;
/// Create a copy of ScheduledTaskIdRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskIdRequestCopyWith<ScheduledTaskIdRequest> get copyWith => _$ScheduledTaskIdRequestCopyWithImpl<ScheduledTaskIdRequest>(this as ScheduledTaskIdRequest, _$identity);

  /// Serializes this ScheduledTaskIdRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskIdRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskIdRequest&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskIdRequest;
  return Object.hash(runtimeType,_this.taskId);
}

@override
String toString() {
  final _this = this as ScheduledTaskIdRequest;
  return 'ScheduledTaskIdRequest(taskId: ${_this.taskId})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskIdRequestCopyWith<$Res>  {
  factory $ScheduledTaskIdRequestCopyWith(ScheduledTaskIdRequest value, $Res Function(ScheduledTaskIdRequest) _then) = _$ScheduledTaskIdRequestCopyWithImpl;
@useResult
$Res call({
 String taskId
});




}
/// @nodoc
class _$ScheduledTaskIdRequestCopyWithImpl<$Res>
    implements $ScheduledTaskIdRequestCopyWith<$Res> {
  _$ScheduledTaskIdRequestCopyWithImpl(this._self, this._then);

  final ScheduledTaskIdRequest _self;
  final $Res Function(ScheduledTaskIdRequest) _then;

/// Create a copy of ScheduledTaskIdRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskId = null,}) {
  return _then(ScheduledTaskIdRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskIdRequest implements ScheduledTaskIdRequest {
  const _ScheduledTaskIdRequest({required this.taskId});
  factory _ScheduledTaskIdRequest.fromJson(Map<String, dynamic> json) => _$ScheduledTaskIdRequestFromJson(json);

@override final  String taskId;

/// Create a copy of ScheduledTaskIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskIdRequestCopyWith<_ScheduledTaskIdRequest> get copyWith => __$ScheduledTaskIdRequestCopyWithImpl<_ScheduledTaskIdRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskIdRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskIdRequest&&(identical(other.taskId, taskId) || other.taskId == taskId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,taskId);
}

@override
String toString() {
    return 'ScheduledTaskIdRequest(taskId: $taskId)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskIdRequestCopyWith<$Res> implements $ScheduledTaskIdRequestCopyWith<$Res> {
  factory _$ScheduledTaskIdRequestCopyWith(_ScheduledTaskIdRequest value, $Res Function(_ScheduledTaskIdRequest) _then) = __$ScheduledTaskIdRequestCopyWithImpl;
@override @useResult
$Res call({
 String taskId
});




}
/// @nodoc
class __$ScheduledTaskIdRequestCopyWithImpl<$Res>
    implements _$ScheduledTaskIdRequestCopyWith<$Res> {
  __$ScheduledTaskIdRequestCopyWithImpl(this._self, this._then);

  final _ScheduledTaskIdRequest _self;
  final $Res Function(_ScheduledTaskIdRequest) _then;

/// Create a copy of ScheduledTaskIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskId = null,}) {
  return _then(_ScheduledTaskIdRequest(
taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ScheduledTaskResponse {

 ScheduledTask get task;
/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskResponseCopyWith<ScheduledTaskResponse> get copyWith => _$ScheduledTaskResponseCopyWithImpl<ScheduledTaskResponse>(this as ScheduledTaskResponse, _$identity);

  /// Serializes this ScheduledTaskResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskResponse&&(identical(other.task, _this.task) || other.task == _this.task));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskResponse;
  return Object.hash(runtimeType,_this.task);
}

@override
String toString() {
  final _this = this as ScheduledTaskResponse;
  return 'ScheduledTaskResponse(task: ${_this.task})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskResponseCopyWith<$Res>  {
  factory $ScheduledTaskResponseCopyWith(ScheduledTaskResponse value, $Res Function(ScheduledTaskResponse) _then) = _$ScheduledTaskResponseCopyWithImpl;
@useResult
$Res call({
 ScheduledTask task
});


$ScheduledTaskCopyWith<$Res> get task;

}
/// @nodoc
class _$ScheduledTaskResponseCopyWithImpl<$Res>
    implements $ScheduledTaskResponseCopyWith<$Res> {
  _$ScheduledTaskResponseCopyWithImpl(this._self, this._then);

  final ScheduledTaskResponse _self;
  final $Res Function(ScheduledTaskResponse) _then;

/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? task = null,}) {
  return _then(ScheduledTaskResponse(
task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as ScheduledTask,
  ));
}
/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskCopyWith<$Res> get task {
  
  return $ScheduledTaskCopyWith<$Res>(_self.task, (value) {
    return _then(_self.copyWith(task: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskResponse implements ScheduledTaskResponse {
  const _ScheduledTaskResponse({required this.task});
  factory _ScheduledTaskResponse.fromJson(Map<String, dynamic> json) => _$ScheduledTaskResponseFromJson(json);

@override final  ScheduledTask task;

/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskResponseCopyWith<_ScheduledTaskResponse> get copyWith => __$ScheduledTaskResponseCopyWithImpl<_ScheduledTaskResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskResponse&&(identical(other.task, task) || other.task == task));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,task);
}

@override
String toString() {
    return 'ScheduledTaskResponse(task: $task)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskResponseCopyWith<$Res> implements $ScheduledTaskResponseCopyWith<$Res> {
  factory _$ScheduledTaskResponseCopyWith(_ScheduledTaskResponse value, $Res Function(_ScheduledTaskResponse) _then) = __$ScheduledTaskResponseCopyWithImpl;
@override @useResult
$Res call({
 ScheduledTask task
});


@override $ScheduledTaskCopyWith<$Res> get task;

}
/// @nodoc
class __$ScheduledTaskResponseCopyWithImpl<$Res>
    implements _$ScheduledTaskResponseCopyWith<$Res> {
  __$ScheduledTaskResponseCopyWithImpl(this._self, this._then);

  final _ScheduledTaskResponse _self;
  final $Res Function(_ScheduledTaskResponse) _then;

/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? task = null,}) {
  return _then(_ScheduledTaskResponse(
task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as ScheduledTask,
  ));
}

/// Create a copy of ScheduledTaskResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskCopyWith<$Res> get task {
  
  return $ScheduledTaskCopyWith<$Res>(_self.task, (value) {
    return _then(_self.copyWith(task: value));
  });
}
}


/// @nodoc
mixin _$ScheduledTaskRunListResponse {

 List<ScheduledTaskRun> get items;
/// Create a copy of ScheduledTaskRunListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskRunListResponseCopyWith<ScheduledTaskRunListResponse> get copyWith => _$ScheduledTaskRunListResponseCopyWithImpl<ScheduledTaskRunListResponse>(this as ScheduledTaskRunListResponse, _$identity);

  /// Serializes this ScheduledTaskRunListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskRunListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunListResponse&&const DeepCollectionEquality().equals(other.items, _this.items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskRunListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as ScheduledTaskRunListResponse;
  return 'ScheduledTaskRunListResponse(items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskRunListResponseCopyWith<$Res>  {
  factory $ScheduledTaskRunListResponseCopyWith(ScheduledTaskRunListResponse value, $Res Function(ScheduledTaskRunListResponse) _then) = _$ScheduledTaskRunListResponseCopyWithImpl;
@useResult
$Res call({
 List<ScheduledTaskRun> items
});




}
/// @nodoc
class _$ScheduledTaskRunListResponseCopyWithImpl<$Res>
    implements $ScheduledTaskRunListResponseCopyWith<$Res> {
  _$ScheduledTaskRunListResponseCopyWithImpl(this._self, this._then);

  final ScheduledTaskRunListResponse _self;
  final $Res Function(ScheduledTaskRunListResponse) _then;

/// Create a copy of ScheduledTaskRunListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(ScheduledTaskRunListResponse(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ScheduledTaskRun>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskRunListResponse implements ScheduledTaskRunListResponse {
  const _ScheduledTaskRunListResponse({required  List<ScheduledTaskRun> items}): _items = items;
  factory _ScheduledTaskRunListResponse.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunListResponseFromJson(json);

 final  List<ScheduledTaskRun> _items;
@override List<ScheduledTaskRun> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ScheduledTaskRunListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskRunListResponseCopyWith<_ScheduledTaskRunListResponse> get copyWith => __$ScheduledTaskRunListResponseCopyWithImpl<_ScheduledTaskRunListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskRunListResponse&&const DeepCollectionEquality().equals(other.items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'ScheduledTaskRunListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskRunListResponseCopyWith<$Res> implements $ScheduledTaskRunListResponseCopyWith<$Res> {
  factory _$ScheduledTaskRunListResponseCopyWith(_ScheduledTaskRunListResponse value, $Res Function(_ScheduledTaskRunListResponse) _then) = __$ScheduledTaskRunListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<ScheduledTaskRun> items
});




}
/// @nodoc
class __$ScheduledTaskRunListResponseCopyWithImpl<$Res>
    implements _$ScheduledTaskRunListResponseCopyWith<$Res> {
  __$ScheduledTaskRunListResponseCopyWithImpl(this._self, this._then);

  final _ScheduledTaskRunListResponse _self;
  final $Res Function(_ScheduledTaskRunListResponse) _then;

/// Create a copy of ScheduledTaskRunListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_ScheduledTaskRunListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ScheduledTaskRun>,
  ));
}


}


/// @nodoc
mixin _$ScheduledTaskRunResponse {

 ScheduledTaskRun get run;
/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskRunResponseCopyWith<ScheduledTaskRunResponse> get copyWith => _$ScheduledTaskRunResponseCopyWithImpl<ScheduledTaskRunResponse>(this as ScheduledTaskRunResponse, _$identity);

  /// Serializes this ScheduledTaskRunResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskRunResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskRunResponse&&(identical(other.run, _this.run) || other.run == _this.run));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskRunResponse;
  return Object.hash(runtimeType,_this.run);
}

@override
String toString() {
  final _this = this as ScheduledTaskRunResponse;
  return 'ScheduledTaskRunResponse(run: ${_this.run})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskRunResponseCopyWith<$Res>  {
  factory $ScheduledTaskRunResponseCopyWith(ScheduledTaskRunResponse value, $Res Function(ScheduledTaskRunResponse) _then) = _$ScheduledTaskRunResponseCopyWithImpl;
@useResult
$Res call({
 ScheduledTaskRun run
});


$ScheduledTaskRunCopyWith<$Res> get run;

}
/// @nodoc
class _$ScheduledTaskRunResponseCopyWithImpl<$Res>
    implements $ScheduledTaskRunResponseCopyWith<$Res> {
  _$ScheduledTaskRunResponseCopyWithImpl(this._self, this._then);

  final ScheduledTaskRunResponse _self;
  final $Res Function(ScheduledTaskRunResponse) _then;

/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? run = null,}) {
  return _then(ScheduledTaskRunResponse(
run: null == run ? _self.run : run // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRun,
  ));
}
/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskRunCopyWith<$Res> get run {
  
  return $ScheduledTaskRunCopyWith<$Res>(_self.run, (value) {
    return _then(_self.copyWith(run: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskRunResponse implements ScheduledTaskRunResponse {
  const _ScheduledTaskRunResponse({required this.run});
  factory _ScheduledTaskRunResponse.fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunResponseFromJson(json);

@override final  ScheduledTaskRun run;

/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskRunResponseCopyWith<_ScheduledTaskRunResponse> get copyWith => __$ScheduledTaskRunResponseCopyWithImpl<_ScheduledTaskRunResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskRunResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskRunResponse&&(identical(other.run, run) || other.run == run));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,run);
}

@override
String toString() {
    return 'ScheduledTaskRunResponse(run: $run)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskRunResponseCopyWith<$Res> implements $ScheduledTaskRunResponseCopyWith<$Res> {
  factory _$ScheduledTaskRunResponseCopyWith(_ScheduledTaskRunResponse value, $Res Function(_ScheduledTaskRunResponse) _then) = __$ScheduledTaskRunResponseCopyWithImpl;
@override @useResult
$Res call({
 ScheduledTaskRun run
});


@override $ScheduledTaskRunCopyWith<$Res> get run;

}
/// @nodoc
class __$ScheduledTaskRunResponseCopyWithImpl<$Res>
    implements _$ScheduledTaskRunResponseCopyWith<$Res> {
  __$ScheduledTaskRunResponseCopyWithImpl(this._self, this._then);

  final _ScheduledTaskRunResponse _self;
  final $Res Function(_ScheduledTaskRunResponse) _then;

/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? run = null,}) {
  return _then(_ScheduledTaskRunResponse(
run: null == run ? _self.run : run // ignore: cast_nullable_to_non_nullable
as ScheduledTaskRun,
  ));
}

/// Create a copy of ScheduledTaskRunResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduledTaskRunCopyWith<$Res> get run {
  
  return $ScheduledTaskRunCopyWith<$Res>(_self.run, (value) {
    return _then(_self.copyWith(run: value));
  });
}
}


/// @nodoc
mixin _$ScheduledTaskErrorResponse {

@JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) ScheduledTaskErrorCode get code;
/// Create a copy of ScheduledTaskErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTaskErrorResponseCopyWith<ScheduledTaskErrorResponse> get copyWith => _$ScheduledTaskErrorResponseCopyWithImpl<ScheduledTaskErrorResponse>(this as ScheduledTaskErrorResponse, _$identity);

  /// Serializes this ScheduledTaskErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduledTaskErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTaskErrorResponse&&(identical(other.code, _this.code) || other.code == _this.code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduledTaskErrorResponse;
  return Object.hash(runtimeType,_this.code);
}

@override
String toString() {
  final _this = this as ScheduledTaskErrorResponse;
  return 'ScheduledTaskErrorResponse(code: ${_this.code})';
}


}

/// @nodoc
abstract mixin class $ScheduledTaskErrorResponseCopyWith<$Res>  {
  factory $ScheduledTaskErrorResponseCopyWith(ScheduledTaskErrorResponse value, $Res Function(ScheduledTaskErrorResponse) _then) = _$ScheduledTaskErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) ScheduledTaskErrorCode code
});




}
/// @nodoc
class _$ScheduledTaskErrorResponseCopyWithImpl<$Res>
    implements $ScheduledTaskErrorResponseCopyWith<$Res> {
  _$ScheduledTaskErrorResponseCopyWithImpl(this._self, this._then);

  final ScheduledTaskErrorResponse _self;
  final $Res Function(ScheduledTaskErrorResponse) _then;

/// Create a copy of ScheduledTaskErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,}) {
  return _then(ScheduledTaskErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ScheduledTaskErrorCode,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ScheduledTaskErrorResponse implements ScheduledTaskErrorResponse {
  const _ScheduledTaskErrorResponse({@JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) required this.code});
  factory _ScheduledTaskErrorResponse.fromJson(Map<String, dynamic> json) => _$ScheduledTaskErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) final  ScheduledTaskErrorCode code;

/// Create a copy of ScheduledTaskErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTaskErrorResponseCopyWith<_ScheduledTaskErrorResponse> get copyWith => __$ScheduledTaskErrorResponseCopyWithImpl<_ScheduledTaskErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTaskErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTaskErrorResponse&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code);
}

@override
String toString() {
    return 'ScheduledTaskErrorResponse(code: $code)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTaskErrorResponseCopyWith<$Res> implements $ScheduledTaskErrorResponseCopyWith<$Res> {
  factory _$ScheduledTaskErrorResponseCopyWith(_ScheduledTaskErrorResponse value, $Res Function(_ScheduledTaskErrorResponse) _then) = __$ScheduledTaskErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) ScheduledTaskErrorCode code
});




}
/// @nodoc
class __$ScheduledTaskErrorResponseCopyWithImpl<$Res>
    implements _$ScheduledTaskErrorResponseCopyWith<$Res> {
  __$ScheduledTaskErrorResponseCopyWithImpl(this._self, this._then);

  final _ScheduledTaskErrorResponse _self;
  final $Res Function(_ScheduledTaskErrorResponse) _then;

/// Create a copy of ScheduledTaskErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(_ScheduledTaskErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ScheduledTaskErrorCode,
  ));
}


}

// dart format on
