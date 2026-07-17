// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_app_server_api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexNotificationParamsDto {

 String? get threadId; String? get turnId; CodexThreadDto? get thread; CodexTurnDto? get turn; String? get threadName; CodexThreadStatusDto? get status; CodexItemDto? get item; String? get itemId; String? get partId; String? get delta; String? get model; String? get modelProvider; String? get cwd;
/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexNotificationParamsDtoCopyWith<CodexNotificationParamsDto> get copyWith => _$CodexNotificationParamsDtoCopyWithImpl<CodexNotificationParamsDto>(this as CodexNotificationParamsDto, _$identity);

  /// Serializes this CodexNotificationParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexNotificationParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.turn, turn) || other.turn == turn)&&(identical(other.threadName, threadName) || other.threadName == threadName)&&(identical(other.status, status) || other.status == status)&&(identical(other.item, item) || other.item == item)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.partId, partId) || other.partId == partId)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,thread,turn,threadName,status,item,itemId,partId,delta,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexNotificationParamsDto(threadId: $threadId, turnId: $turnId, thread: $thread, turn: $turn, threadName: $threadName, status: $status, item: $item, itemId: $itemId, partId: $partId, delta: $delta, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class $CodexNotificationParamsDtoCopyWith<$Res>  {
  factory $CodexNotificationParamsDtoCopyWith(CodexNotificationParamsDto value, $Res Function(CodexNotificationParamsDto) _then) = _$CodexNotificationParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? threadId, String? turnId, CodexThreadDto? thread, CodexTurnDto? turn, String? threadName, CodexThreadStatusDto? status, CodexItemDto? item, String? itemId, String? partId, String? delta, String? model, String? modelProvider, String? cwd
});


$CodexThreadDtoCopyWith<$Res>? get thread;$CodexTurnDtoCopyWith<$Res>? get turn;$CodexThreadStatusDtoCopyWith<$Res>? get status;$CodexItemDtoCopyWith<$Res>? get item;

}
/// @nodoc
class _$CodexNotificationParamsDtoCopyWithImpl<$Res>
    implements $CodexNotificationParamsDtoCopyWith<$Res> {
  _$CodexNotificationParamsDtoCopyWithImpl(this._self, this._then);

  final CodexNotificationParamsDto _self;
  final $Res Function(CodexNotificationParamsDto) _then;

/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? thread = freezed,Object? turn = freezed,Object? threadName = freezed,Object? status = freezed,Object? item = freezed,Object? itemId = freezed,Object? partId = freezed,Object? delta = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_self.copyWith(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,threadName: freezed == threadName ? _self.threadName : threadName // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexThreadStatusDto?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexItemDto?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,partId: freezed == partId ? _self.partId : partId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadStatusDtoCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $CodexThreadStatusDtoCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexItemDtoCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $CodexItemDtoCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexNotificationParamsDto implements CodexNotificationParamsDto {
  const _CodexNotificationParamsDto({required this.threadId, required this.turnId, required this.thread, required this.turn, required this.threadName, required this.status, required this.item, required this.itemId, required this.partId, required this.delta, required this.model, required this.modelProvider, required this.cwd});
  factory _CodexNotificationParamsDto.fromJson(Map<String, dynamic> json) => _$CodexNotificationParamsDtoFromJson(json);

@override final  String? threadId;
@override final  String? turnId;
@override final  CodexThreadDto? thread;
@override final  CodexTurnDto? turn;
@override final  String? threadName;
@override final  CodexThreadStatusDto? status;
@override final  CodexItemDto? item;
@override final  String? itemId;
@override final  String? partId;
@override final  String? delta;
@override final  String? model;
@override final  String? modelProvider;
@override final  String? cwd;

/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexNotificationParamsDtoCopyWith<_CodexNotificationParamsDto> get copyWith => __$CodexNotificationParamsDtoCopyWithImpl<_CodexNotificationParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexNotificationParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexNotificationParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.turn, turn) || other.turn == turn)&&(identical(other.threadName, threadName) || other.threadName == threadName)&&(identical(other.status, status) || other.status == status)&&(identical(other.item, item) || other.item == item)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.partId, partId) || other.partId == partId)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,thread,turn,threadName,status,item,itemId,partId,delta,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexNotificationParamsDto(threadId: $threadId, turnId: $turnId, thread: $thread, turn: $turn, threadName: $threadName, status: $status, item: $item, itemId: $itemId, partId: $partId, delta: $delta, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class _$CodexNotificationParamsDtoCopyWith<$Res> implements $CodexNotificationParamsDtoCopyWith<$Res> {
  factory _$CodexNotificationParamsDtoCopyWith(_CodexNotificationParamsDto value, $Res Function(_CodexNotificationParamsDto) _then) = __$CodexNotificationParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? threadId, String? turnId, CodexThreadDto? thread, CodexTurnDto? turn, String? threadName, CodexThreadStatusDto? status, CodexItemDto? item, String? itemId, String? partId, String? delta, String? model, String? modelProvider, String? cwd
});


@override $CodexThreadDtoCopyWith<$Res>? get thread;@override $CodexTurnDtoCopyWith<$Res>? get turn;@override $CodexThreadStatusDtoCopyWith<$Res>? get status;@override $CodexItemDtoCopyWith<$Res>? get item;

}
/// @nodoc
class __$CodexNotificationParamsDtoCopyWithImpl<$Res>
    implements _$CodexNotificationParamsDtoCopyWith<$Res> {
  __$CodexNotificationParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexNotificationParamsDto _self;
  final $Res Function(_CodexNotificationParamsDto) _then;

/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? thread = freezed,Object? turn = freezed,Object? threadName = freezed,Object? status = freezed,Object? item = freezed,Object? itemId = freezed,Object? partId = freezed,Object? delta = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_CodexNotificationParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,threadName: freezed == threadName ? _self.threadName : threadName // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexThreadStatusDto?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexItemDto?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,partId: freezed == partId ? _self.partId : partId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadStatusDtoCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $CodexThreadStatusDtoCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}/// Create a copy of CodexNotificationParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexItemDtoCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $CodexItemDtoCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$CodexThreadStatusDto {

 String? get type; CodexThreadStatusDto? get status;
/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadStatusDtoCopyWith<CodexThreadStatusDto> get copyWith => _$CodexThreadStatusDtoCopyWithImpl<CodexThreadStatusDto>(this as CodexThreadStatusDto, _$identity);

  /// Serializes this CodexThreadStatusDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadStatusDto&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,status);

@override
String toString() {
  return 'CodexThreadStatusDto(type: $type, status: $status)';
}


}

/// @nodoc
abstract mixin class $CodexThreadStatusDtoCopyWith<$Res>  {
  factory $CodexThreadStatusDtoCopyWith(CodexThreadStatusDto value, $Res Function(CodexThreadStatusDto) _then) = _$CodexThreadStatusDtoCopyWithImpl;
@useResult
$Res call({
 String? type, CodexThreadStatusDto? status
});


$CodexThreadStatusDtoCopyWith<$Res>? get status;

}
/// @nodoc
class _$CodexThreadStatusDtoCopyWithImpl<$Res>
    implements $CodexThreadStatusDtoCopyWith<$Res> {
  _$CodexThreadStatusDtoCopyWithImpl(this._self, this._then);

  final CodexThreadStatusDto _self;
  final $Res Function(CodexThreadStatusDto) _then;

/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexThreadStatusDto?,
  ));
}
/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadStatusDtoCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $CodexThreadStatusDtoCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexThreadStatusDto implements CodexThreadStatusDto {
  const _CodexThreadStatusDto({required this.type, required this.status});
  factory _CodexThreadStatusDto.fromJson(Map<String, dynamic> json) => _$CodexThreadStatusDtoFromJson(json);

@override final  String? type;
@override final  CodexThreadStatusDto? status;

/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadStatusDtoCopyWith<_CodexThreadStatusDto> get copyWith => __$CodexThreadStatusDtoCopyWithImpl<_CodexThreadStatusDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexThreadStatusDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadStatusDto&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,status);

@override
String toString() {
  return 'CodexThreadStatusDto(type: $type, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadStatusDtoCopyWith<$Res> implements $CodexThreadStatusDtoCopyWith<$Res> {
  factory _$CodexThreadStatusDtoCopyWith(_CodexThreadStatusDto value, $Res Function(_CodexThreadStatusDto) _then) = __$CodexThreadStatusDtoCopyWithImpl;
@override @useResult
$Res call({
 String? type, CodexThreadStatusDto? status
});


@override $CodexThreadStatusDtoCopyWith<$Res>? get status;

}
/// @nodoc
class __$CodexThreadStatusDtoCopyWithImpl<$Res>
    implements _$CodexThreadStatusDtoCopyWith<$Res> {
  __$CodexThreadStatusDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadStatusDto _self;
  final $Res Function(_CodexThreadStatusDto) _then;

/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? status = freezed,}) {
  return _then(_CodexThreadStatusDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexThreadStatusDto?,
  ));
}

/// Create a copy of CodexThreadStatusDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadStatusDtoCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $CodexThreadStatusDtoCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// @nodoc
mixin _$CodexItemDto {

 String? get type; String? get id;@CodexTextValuesMapper() List<String> get content;@CodexTextValuesMapper() List<String> get summary; String? get text; String? get command; String? get status; String? get aggregatedOutput; List<CodexFileChangeDto> get changes; String? get tool; String? get server; CodexMcpResultDto? get result; CodexErrorDto? get error; String? get query;
/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexItemDtoCopyWith<CodexItemDto> get copyWith => _$CodexItemDtoCopyWithImpl<CodexItemDto>(this as CodexItemDto, _$identity);

  /// Serializes this CodexItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.content, content)&&const DeepCollectionEquality().equals(other.summary, summary)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.status, status) || other.status == status)&&(identical(other.aggregatedOutput, aggregatedOutput) || other.aggregatedOutput == aggregatedOutput)&&const DeepCollectionEquality().equals(other.changes, changes)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.server, server) || other.server == server)&&(identical(other.result, result) || other.result == result)&&(identical(other.error, error) || other.error == error)&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,const DeepCollectionEquality().hash(content),const DeepCollectionEquality().hash(summary),text,command,status,aggregatedOutput,const DeepCollectionEquality().hash(changes),tool,server,result,error,query);

@override
String toString() {
  return 'CodexItemDto(type: $type, id: $id, content: $content, summary: $summary, text: $text, command: $command, status: $status, aggregatedOutput: $aggregatedOutput, changes: $changes, tool: $tool, server: $server, result: $result, error: $error, query: $query)';
}


}

/// @nodoc
abstract mixin class $CodexItemDtoCopyWith<$Res>  {
  factory $CodexItemDtoCopyWith(CodexItemDto value, $Res Function(CodexItemDto) _then) = _$CodexItemDtoCopyWithImpl;
@useResult
$Res call({
 String? type, String? id,@CodexTextValuesMapper() List<String> content,@CodexTextValuesMapper() List<String> summary, String? text, String? command, String? status, String? aggregatedOutput, List<CodexFileChangeDto> changes, String? tool, String? server, CodexMcpResultDto? result, CodexErrorDto? error, String? query
});


$CodexMcpResultDtoCopyWith<$Res>? get result;$CodexErrorDtoCopyWith<$Res>? get error;

}
/// @nodoc
class _$CodexItemDtoCopyWithImpl<$Res>
    implements $CodexItemDtoCopyWith<$Res> {
  _$CodexItemDtoCopyWithImpl(this._self, this._then);

  final CodexItemDto _self;
  final $Res Function(CodexItemDto) _then;

/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? id = freezed,Object? content = null,Object? summary = null,Object? text = freezed,Object? command = freezed,Object? status = freezed,Object? aggregatedOutput = freezed,Object? changes = null,Object? tool = freezed,Object? server = freezed,Object? result = freezed,Object? error = freezed,Object? query = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<String>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,aggregatedOutput: freezed == aggregatedOutput ? _self.aggregatedOutput : aggregatedOutput // ignore: cast_nullable_to_non_nullable
as String?,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<CodexFileChangeDto>,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as CodexMcpResultDto?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as CodexErrorDto?,query: freezed == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexMcpResultDtoCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $CodexMcpResultDtoCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexErrorDtoCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $CodexErrorDtoCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexItemDto implements CodexItemDto {
  const _CodexItemDto({required this.type, required this.id, @CodexTextValuesMapper() required final  List<String> content, @CodexTextValuesMapper() required final  List<String> summary, required this.text, required this.command, required this.status, required this.aggregatedOutput, final  List<CodexFileChangeDto> changes = const <CodexFileChangeDto>[], required this.tool, required this.server, required this.result, required this.error, required this.query}): _content = content,_summary = summary,_changes = changes;
  factory _CodexItemDto.fromJson(Map<String, dynamic> json) => _$CodexItemDtoFromJson(json);

@override final  String? type;
@override final  String? id;
 final  List<String> _content;
@override@CodexTextValuesMapper() List<String> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  List<String> _summary;
@override@CodexTextValuesMapper() List<String> get summary {
  if (_summary is EqualUnmodifiableListView) return _summary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_summary);
}

@override final  String? text;
@override final  String? command;
@override final  String? status;
@override final  String? aggregatedOutput;
 final  List<CodexFileChangeDto> _changes;
@override@JsonKey() List<CodexFileChangeDto> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}

@override final  String? tool;
@override final  String? server;
@override final  CodexMcpResultDto? result;
@override final  CodexErrorDto? error;
@override final  String? query;

/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexItemDtoCopyWith<_CodexItemDto> get copyWith => __$CodexItemDtoCopyWithImpl<_CodexItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._content, _content)&&const DeepCollectionEquality().equals(other._summary, _summary)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.status, status) || other.status == status)&&(identical(other.aggregatedOutput, aggregatedOutput) || other.aggregatedOutput == aggregatedOutput)&&const DeepCollectionEquality().equals(other._changes, _changes)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.server, server) || other.server == server)&&(identical(other.result, result) || other.result == result)&&(identical(other.error, error) || other.error == error)&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,const DeepCollectionEquality().hash(_content),const DeepCollectionEquality().hash(_summary),text,command,status,aggregatedOutput,const DeepCollectionEquality().hash(_changes),tool,server,result,error,query);

@override
String toString() {
  return 'CodexItemDto(type: $type, id: $id, content: $content, summary: $summary, text: $text, command: $command, status: $status, aggregatedOutput: $aggregatedOutput, changes: $changes, tool: $tool, server: $server, result: $result, error: $error, query: $query)';
}


}

/// @nodoc
abstract mixin class _$CodexItemDtoCopyWith<$Res> implements $CodexItemDtoCopyWith<$Res> {
  factory _$CodexItemDtoCopyWith(_CodexItemDto value, $Res Function(_CodexItemDto) _then) = __$CodexItemDtoCopyWithImpl;
@override @useResult
$Res call({
 String? type, String? id,@CodexTextValuesMapper() List<String> content,@CodexTextValuesMapper() List<String> summary, String? text, String? command, String? status, String? aggregatedOutput, List<CodexFileChangeDto> changes, String? tool, String? server, CodexMcpResultDto? result, CodexErrorDto? error, String? query
});


@override $CodexMcpResultDtoCopyWith<$Res>? get result;@override $CodexErrorDtoCopyWith<$Res>? get error;

}
/// @nodoc
class __$CodexItemDtoCopyWithImpl<$Res>
    implements _$CodexItemDtoCopyWith<$Res> {
  __$CodexItemDtoCopyWithImpl(this._self, this._then);

  final _CodexItemDto _self;
  final $Res Function(_CodexItemDto) _then;

/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? id = freezed,Object? content = null,Object? summary = null,Object? text = freezed,Object? command = freezed,Object? status = freezed,Object? aggregatedOutput = freezed,Object? changes = null,Object? tool = freezed,Object? server = freezed,Object? result = freezed,Object? error = freezed,Object? query = freezed,}) {
  return _then(_CodexItemDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<String>,summary: null == summary ? _self._summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,aggregatedOutput: freezed == aggregatedOutput ? _self.aggregatedOutput : aggregatedOutput // ignore: cast_nullable_to_non_nullable
as String?,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<CodexFileChangeDto>,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as CodexMcpResultDto?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as CodexErrorDto?,query: freezed == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexMcpResultDtoCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $CodexMcpResultDtoCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of CodexItemDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexErrorDtoCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $CodexErrorDtoCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$CodexFileChangeDto {

 String? get path; String? get diff;
/// Create a copy of CodexFileChangeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileChangeDtoCopyWith<CodexFileChangeDto> get copyWith => _$CodexFileChangeDtoCopyWithImpl<CodexFileChangeDto>(this as CodexFileChangeDto, _$identity);

  /// Serializes this CodexFileChangeDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileChangeDto&&(identical(other.path, path) || other.path == path)&&(identical(other.diff, diff) || other.diff == diff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,diff);

@override
String toString() {
  return 'CodexFileChangeDto(path: $path, diff: $diff)';
}


}

/// @nodoc
abstract mixin class $CodexFileChangeDtoCopyWith<$Res>  {
  factory $CodexFileChangeDtoCopyWith(CodexFileChangeDto value, $Res Function(CodexFileChangeDto) _then) = _$CodexFileChangeDtoCopyWithImpl;
@useResult
$Res call({
 String? path, String? diff
});




}
/// @nodoc
class _$CodexFileChangeDtoCopyWithImpl<$Res>
    implements $CodexFileChangeDtoCopyWith<$Res> {
  _$CodexFileChangeDtoCopyWithImpl(this._self, this._then);

  final CodexFileChangeDto _self;
  final $Res Function(CodexFileChangeDto) _then;

/// Create a copy of CodexFileChangeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = freezed,Object? diff = freezed,}) {
  return _then(_self.copyWith(
path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,diff: freezed == diff ? _self.diff : diff // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexFileChangeDto implements CodexFileChangeDto {
  const _CodexFileChangeDto({required this.path, required this.diff});
  factory _CodexFileChangeDto.fromJson(Map<String, dynamic> json) => _$CodexFileChangeDtoFromJson(json);

@override final  String? path;
@override final  String? diff;

/// Create a copy of CodexFileChangeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexFileChangeDtoCopyWith<_CodexFileChangeDto> get copyWith => __$CodexFileChangeDtoCopyWithImpl<_CodexFileChangeDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexFileChangeDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileChangeDto&&(identical(other.path, path) || other.path == path)&&(identical(other.diff, diff) || other.diff == diff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,diff);

@override
String toString() {
  return 'CodexFileChangeDto(path: $path, diff: $diff)';
}


}

/// @nodoc
abstract mixin class _$CodexFileChangeDtoCopyWith<$Res> implements $CodexFileChangeDtoCopyWith<$Res> {
  factory _$CodexFileChangeDtoCopyWith(_CodexFileChangeDto value, $Res Function(_CodexFileChangeDto) _then) = __$CodexFileChangeDtoCopyWithImpl;
@override @useResult
$Res call({
 String? path, String? diff
});




}
/// @nodoc
class __$CodexFileChangeDtoCopyWithImpl<$Res>
    implements _$CodexFileChangeDtoCopyWith<$Res> {
  __$CodexFileChangeDtoCopyWithImpl(this._self, this._then);

  final _CodexFileChangeDto _self;
  final $Res Function(_CodexFileChangeDto) _then;

/// Create a copy of CodexFileChangeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = freezed,Object? diff = freezed,}) {
  return _then(_CodexFileChangeDto(
path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,diff: freezed == diff ? _self.diff : diff // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexMcpResultDto {

@CodexTextValuesMapper() List<String> get content;
/// Create a copy of CodexMcpResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexMcpResultDtoCopyWith<CodexMcpResultDto> get copyWith => _$CodexMcpResultDtoCopyWithImpl<CodexMcpResultDto>(this as CodexMcpResultDto, _$identity);

  /// Serializes this CodexMcpResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpResultDto&&const DeepCollectionEquality().equals(other.content, content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(content));

@override
String toString() {
  return 'CodexMcpResultDto(content: $content)';
}


}

/// @nodoc
abstract mixin class $CodexMcpResultDtoCopyWith<$Res>  {
  factory $CodexMcpResultDtoCopyWith(CodexMcpResultDto value, $Res Function(CodexMcpResultDto) _then) = _$CodexMcpResultDtoCopyWithImpl;
@useResult
$Res call({
@CodexTextValuesMapper() List<String> content
});




}
/// @nodoc
class _$CodexMcpResultDtoCopyWithImpl<$Res>
    implements $CodexMcpResultDtoCopyWith<$Res> {
  _$CodexMcpResultDtoCopyWithImpl(this._self, this._then);

  final CodexMcpResultDto _self;
  final $Res Function(CodexMcpResultDto) _then;

/// Create a copy of CodexMcpResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexMcpResultDto implements CodexMcpResultDto {
  const _CodexMcpResultDto({@CodexTextValuesMapper() required final  List<String> content}): _content = content;
  factory _CodexMcpResultDto.fromJson(Map<String, dynamic> json) => _$CodexMcpResultDtoFromJson(json);

 final  List<String> _content;
@override@CodexTextValuesMapper() List<String> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}


/// Create a copy of CodexMcpResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexMcpResultDtoCopyWith<_CodexMcpResultDto> get copyWith => __$CodexMcpResultDtoCopyWithImpl<_CodexMcpResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexMcpResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpResultDto&&const DeepCollectionEquality().equals(other._content, _content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content));

@override
String toString() {
  return 'CodexMcpResultDto(content: $content)';
}


}

/// @nodoc
abstract mixin class _$CodexMcpResultDtoCopyWith<$Res> implements $CodexMcpResultDtoCopyWith<$Res> {
  factory _$CodexMcpResultDtoCopyWith(_CodexMcpResultDto value, $Res Function(_CodexMcpResultDto) _then) = __$CodexMcpResultDtoCopyWithImpl;
@override @useResult
$Res call({
@CodexTextValuesMapper() List<String> content
});




}
/// @nodoc
class __$CodexMcpResultDtoCopyWithImpl<$Res>
    implements _$CodexMcpResultDtoCopyWith<$Res> {
  __$CodexMcpResultDtoCopyWithImpl(this._self, this._then);

  final _CodexMcpResultDto _self;
  final $Res Function(_CodexMcpResultDto) _then;

/// Create a copy of CodexMcpResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(_CodexMcpResultDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$CodexErrorDto {

 String? get message;
/// Create a copy of CodexErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexErrorDtoCopyWith<CodexErrorDto> get copyWith => _$CodexErrorDtoCopyWithImpl<CodexErrorDto>(this as CodexErrorDto, _$identity);

  /// Serializes this CodexErrorDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexErrorDto&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'CodexErrorDto(message: $message)';
}


}

/// @nodoc
abstract mixin class $CodexErrorDtoCopyWith<$Res>  {
  factory $CodexErrorDtoCopyWith(CodexErrorDto value, $Res Function(CodexErrorDto) _then) = _$CodexErrorDtoCopyWithImpl;
@useResult
$Res call({
 String? message
});




}
/// @nodoc
class _$CodexErrorDtoCopyWithImpl<$Res>
    implements $CodexErrorDtoCopyWith<$Res> {
  _$CodexErrorDtoCopyWithImpl(this._self, this._then);

  final CodexErrorDto _self;
  final $Res Function(CodexErrorDto) _then;

/// Create a copy of CodexErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = freezed,}) {
  return _then(_self.copyWith(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexErrorDto implements CodexErrorDto {
  const _CodexErrorDto({required this.message});
  factory _CodexErrorDto.fromJson(Map<String, dynamic> json) => _$CodexErrorDtoFromJson(json);

@override final  String? message;

/// Create a copy of CodexErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexErrorDtoCopyWith<_CodexErrorDto> get copyWith => __$CodexErrorDtoCopyWithImpl<_CodexErrorDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexErrorDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexErrorDto&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'CodexErrorDto(message: $message)';
}


}

/// @nodoc
abstract mixin class _$CodexErrorDtoCopyWith<$Res> implements $CodexErrorDtoCopyWith<$Res> {
  factory _$CodexErrorDtoCopyWith(_CodexErrorDto value, $Res Function(_CodexErrorDto) _then) = __$CodexErrorDtoCopyWithImpl;
@override @useResult
$Res call({
 String? message
});




}
/// @nodoc
class __$CodexErrorDtoCopyWithImpl<$Res>
    implements _$CodexErrorDtoCopyWith<$Res> {
  __$CodexErrorDtoCopyWithImpl(this._self, this._then);

  final _CodexErrorDto _self;
  final $Res Function(_CodexErrorDto) _then;

/// Create a copy of CodexErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = freezed,}) {
  return _then(_CodexErrorDto(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexThreadResponseDto {

 CodexThreadDto? get thread; String? get model; String? get modelProvider; String? get cwd;
/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadResponseDtoCopyWith<CodexThreadResponseDto> get copyWith => _$CodexThreadResponseDtoCopyWithImpl<CodexThreadResponseDto>(this as CodexThreadResponseDto, _$identity);

  /// Serializes this CodexThreadResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadResponseDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadResponseDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class $CodexThreadResponseDtoCopyWith<$Res>  {
  factory $CodexThreadResponseDtoCopyWith(CodexThreadResponseDto value, $Res Function(CodexThreadResponseDto) _then) = _$CodexThreadResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


$CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class _$CodexThreadResponseDtoCopyWithImpl<$Res>
    implements $CodexThreadResponseDtoCopyWith<$Res> {
  _$CodexThreadResponseDtoCopyWithImpl(this._self, this._then);

  final CodexThreadResponseDto _self;
  final $Res Function(CodexThreadResponseDto) _then;

/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_self.copyWith(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexThreadResponseDto implements CodexThreadResponseDto {
  const _CodexThreadResponseDto({required this.thread, required this.model, required this.modelProvider, required this.cwd});
  factory _CodexThreadResponseDto.fromJson(Map<String, dynamic> json) => _$CodexThreadResponseDtoFromJson(json);

@override final  CodexThreadDto? thread;
@override final  String? model;
@override final  String? modelProvider;
@override final  String? cwd;

/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadResponseDtoCopyWith<_CodexThreadResponseDto> get copyWith => __$CodexThreadResponseDtoCopyWithImpl<_CodexThreadResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexThreadResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadResponseDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadResponseDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadResponseDtoCopyWith<$Res> implements $CodexThreadResponseDtoCopyWith<$Res> {
  factory _$CodexThreadResponseDtoCopyWith(_CodexThreadResponseDto value, $Res Function(_CodexThreadResponseDto) _then) = __$CodexThreadResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


@override $CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class __$CodexThreadResponseDtoCopyWithImpl<$Res>
    implements _$CodexThreadResponseDtoCopyWith<$Res> {
  __$CodexThreadResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadResponseDto _self;
  final $Res Function(_CodexThreadResponseDto) _then;

/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_CodexThreadResponseDto(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexThreadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}


/// @nodoc
mixin _$CodexThreadDto {

 String? get id; String? get cwd; String? get name; String? get modelProvider; num? get createdAt; num? get updatedAt;
/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<CodexThreadDto> get copyWith => _$CodexThreadDtoCopyWithImpl<CodexThreadDto>(this as CodexThreadDto, _$identity);

  /// Serializes this CodexThreadDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.name, name) || other.name == name)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,name,modelProvider,createdAt,updatedAt);

@override
String toString() {
  return 'CodexThreadDto(id: $id, cwd: $cwd, name: $name, modelProvider: $modelProvider, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CodexThreadDtoCopyWith<$Res>  {
  factory $CodexThreadDtoCopyWith(CodexThreadDto value, $Res Function(CodexThreadDto) _then) = _$CodexThreadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd, String? name, String? modelProvider, num? createdAt, num? updatedAt
});




}
/// @nodoc
class _$CodexThreadDtoCopyWithImpl<$Res>
    implements $CodexThreadDtoCopyWith<$Res> {
  _$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final CodexThreadDto _self;
  final $Res Function(CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,Object? name = freezed,Object? modelProvider = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexThreadDto implements CodexThreadDto {
  const _CodexThreadDto({required this.id, required this.cwd, required this.name, required this.modelProvider, required this.createdAt, required this.updatedAt});
  factory _CodexThreadDto.fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;
@override final  String? name;
@override final  String? modelProvider;
@override final  num? createdAt;
@override final  num? updatedAt;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadDtoCopyWith<_CodexThreadDto> get copyWith => __$CodexThreadDtoCopyWithImpl<_CodexThreadDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexThreadDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.name, name) || other.name == name)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,name,modelProvider,createdAt,updatedAt);

@override
String toString() {
  return 'CodexThreadDto(id: $id, cwd: $cwd, name: $name, modelProvider: $modelProvider, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadDtoCopyWith<$Res> implements $CodexThreadDtoCopyWith<$Res> {
  factory _$CodexThreadDtoCopyWith(_CodexThreadDto value, $Res Function(_CodexThreadDto) _then) = __$CodexThreadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd, String? name, String? modelProvider, num? createdAt, num? updatedAt
});




}
/// @nodoc
class __$CodexThreadDtoCopyWithImpl<$Res>
    implements _$CodexThreadDtoCopyWith<$Res> {
  __$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadDto _self;
  final $Res Function(_CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,Object? name = freezed,Object? modelProvider = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_CodexThreadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$CodexTurnResponseDto {

 CodexTurnDto? get turn; String? get turnId; String? get id;
/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnResponseDtoCopyWith<CodexTurnResponseDto> get copyWith => _$CodexTurnResponseDtoCopyWithImpl<CodexTurnResponseDto>(this as CodexTurnResponseDto, _$identity);

  /// Serializes this CodexTurnResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnResponseDto&&(identical(other.turn, turn) || other.turn == turn)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,turn,turnId,id);

@override
String toString() {
  return 'CodexTurnResponseDto(turn: $turn, turnId: $turnId, id: $id)';
}


}

/// @nodoc
abstract mixin class $CodexTurnResponseDtoCopyWith<$Res>  {
  factory $CodexTurnResponseDtoCopyWith(CodexTurnResponseDto value, $Res Function(CodexTurnResponseDto) _then) = _$CodexTurnResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexTurnDto? turn, String? turnId, String? id
});


$CodexTurnDtoCopyWith<$Res>? get turn;

}
/// @nodoc
class _$CodexTurnResponseDtoCopyWithImpl<$Res>
    implements $CodexTurnResponseDtoCopyWith<$Res> {
  _$CodexTurnResponseDtoCopyWithImpl(this._self, this._then);

  final CodexTurnResponseDto _self;
  final $Res Function(CodexTurnResponseDto) _then;

/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? turn = freezed,Object? turnId = freezed,Object? id = freezed,}) {
  return _then(_self.copyWith(
turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexTurnResponseDto implements CodexTurnResponseDto {
  const _CodexTurnResponseDto({required this.turn, required this.turnId, required this.id});
  factory _CodexTurnResponseDto.fromJson(Map<String, dynamic> json) => _$CodexTurnResponseDtoFromJson(json);

@override final  CodexTurnDto? turn;
@override final  String? turnId;
@override final  String? id;

/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexTurnResponseDtoCopyWith<_CodexTurnResponseDto> get copyWith => __$CodexTurnResponseDtoCopyWithImpl<_CodexTurnResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTurnResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTurnResponseDto&&(identical(other.turn, turn) || other.turn == turn)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,turn,turnId,id);

@override
String toString() {
  return 'CodexTurnResponseDto(turn: $turn, turnId: $turnId, id: $id)';
}


}

/// @nodoc
abstract mixin class _$CodexTurnResponseDtoCopyWith<$Res> implements $CodexTurnResponseDtoCopyWith<$Res> {
  factory _$CodexTurnResponseDtoCopyWith(_CodexTurnResponseDto value, $Res Function(_CodexTurnResponseDto) _then) = __$CodexTurnResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexTurnDto? turn, String? turnId, String? id
});


@override $CodexTurnDtoCopyWith<$Res>? get turn;

}
/// @nodoc
class __$CodexTurnResponseDtoCopyWithImpl<$Res>
    implements _$CodexTurnResponseDtoCopyWith<$Res> {
  __$CodexTurnResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexTurnResponseDto _self;
  final $Res Function(_CodexTurnResponseDto) _then;

/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? turn = freezed,Object? turnId = freezed,Object? id = freezed,}) {
  return _then(_CodexTurnResponseDto(
turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexTurnResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}
}


/// @nodoc
mixin _$CodexTurnDto {

 String? get id;
/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<CodexTurnDto> get copyWith => _$CodexTurnDtoCopyWithImpl<CodexTurnDto>(this as CodexTurnDto, _$identity);

  /// Serializes this CodexTurnDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'CodexTurnDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $CodexTurnDtoCopyWith<$Res>  {
  factory $CodexTurnDtoCopyWith(CodexTurnDto value, $Res Function(CodexTurnDto) _then) = _$CodexTurnDtoCopyWithImpl;
@useResult
$Res call({
 String? id
});




}
/// @nodoc
class _$CodexTurnDtoCopyWithImpl<$Res>
    implements $CodexTurnDtoCopyWith<$Res> {
  _$CodexTurnDtoCopyWithImpl(this._self, this._then);

  final CodexTurnDto _self;
  final $Res Function(CodexTurnDto) _then;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexTurnDto implements CodexTurnDto {
  const _CodexTurnDto({required this.id});
  factory _CodexTurnDto.fromJson(Map<String, dynamic> json) => _$CodexTurnDtoFromJson(json);

@override final  String? id;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexTurnDtoCopyWith<_CodexTurnDto> get copyWith => __$CodexTurnDtoCopyWithImpl<_CodexTurnDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTurnDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTurnDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'CodexTurnDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$CodexTurnDtoCopyWith<$Res> implements $CodexTurnDtoCopyWith<$Res> {
  factory _$CodexTurnDtoCopyWith(_CodexTurnDto value, $Res Function(_CodexTurnDto) _then) = __$CodexTurnDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id
});




}
/// @nodoc
class __$CodexTurnDtoCopyWithImpl<$Res>
    implements _$CodexTurnDtoCopyWith<$Res> {
  __$CodexTurnDtoCopyWithImpl(this._self, this._then);

  final _CodexTurnDto _self;
  final $Res Function(_CodexTurnDto) _then;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,}) {
  return _then(_CodexTurnDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexTurnInterruptResponseDto {



  /// Serializes this CodexTurnInterruptResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnInterruptResponseDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexTurnInterruptResponseDto()';
}


}

/// @nodoc
class $CodexTurnInterruptResponseDtoCopyWith<$Res>  {
$CodexTurnInterruptResponseDtoCopyWith(CodexTurnInterruptResponseDto _, $Res Function(CodexTurnInterruptResponseDto) __);
}



/// @nodoc
@JsonSerializable()

class _CodexTurnInterruptResponseDto implements CodexTurnInterruptResponseDto {
  const _CodexTurnInterruptResponseDto();
  factory _CodexTurnInterruptResponseDto.fromJson(Map<String, dynamic> json) => _$CodexTurnInterruptResponseDtoFromJson(json);




@override
Map<String, dynamic> toJson() {
  return _$CodexTurnInterruptResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTurnInterruptResponseDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexTurnInterruptResponseDto()';
}


}





/// @nodoc
mixin _$CodexModelListResponseDto {

 List<CodexModelDto> get data;
/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelListResponseDtoCopyWith<CodexModelListResponseDto> get copyWith => _$CodexModelListResponseDtoCopyWithImpl<CodexModelListResponseDto>(this as CodexModelListResponseDto, _$identity);

  /// Serializes this CodexModelListResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelListResponseDto&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'CodexModelListResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class $CodexModelListResponseDtoCopyWith<$Res>  {
  factory $CodexModelListResponseDtoCopyWith(CodexModelListResponseDto value, $Res Function(CodexModelListResponseDto) _then) = _$CodexModelListResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<CodexModelDto> data
});




}
/// @nodoc
class _$CodexModelListResponseDtoCopyWithImpl<$Res>
    implements $CodexModelListResponseDtoCopyWith<$Res> {
  _$CodexModelListResponseDtoCopyWithImpl(this._self, this._then);

  final CodexModelListResponseDto _self;
  final $Res Function(CodexModelListResponseDto) _then;

/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CodexModelDto>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexModelListResponseDto implements CodexModelListResponseDto {
  const _CodexModelListResponseDto({final  List<CodexModelDto> data = const <CodexModelDto>[]}): _data = data;
  factory _CodexModelListResponseDto.fromJson(Map<String, dynamic> json) => _$CodexModelListResponseDtoFromJson(json);

 final  List<CodexModelDto> _data;
@override@JsonKey() List<CodexModelDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelListResponseDtoCopyWith<_CodexModelListResponseDto> get copyWith => __$CodexModelListResponseDtoCopyWithImpl<_CodexModelListResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexModelListResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelListResponseDto&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'CodexModelListResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CodexModelListResponseDtoCopyWith<$Res> implements $CodexModelListResponseDtoCopyWith<$Res> {
  factory _$CodexModelListResponseDtoCopyWith(_CodexModelListResponseDto value, $Res Function(_CodexModelListResponseDto) _then) = __$CodexModelListResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<CodexModelDto> data
});




}
/// @nodoc
class __$CodexModelListResponseDtoCopyWithImpl<$Res>
    implements _$CodexModelListResponseDtoCopyWith<$Res> {
  __$CodexModelListResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexModelListResponseDto _self;
  final $Res Function(_CodexModelListResponseDto) _then;

/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CodexModelListResponseDto(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CodexModelDto>,
  ));
}


}


/// @nodoc
mixin _$CodexModelDto {

 String? get id; String? get displayName; bool? get hidden; bool? get isDefault; String? get defaultReasoningEffort;@CodexReasoningEffortsMapper() List<CodexReasoningEffortDto> get supportedReasoningEfforts;
/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelDtoCopyWith<CodexModelDto> get copyWith => _$CodexModelDtoCopyWithImpl<CodexModelDto>(this as CodexModelDto, _$identity);

  /// Serializes this CodexModelDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.defaultReasoningEffort, defaultReasoningEffort) || other.defaultReasoningEffort == defaultReasoningEffort)&&const DeepCollectionEquality().equals(other.supportedReasoningEfforts, supportedReasoningEfforts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,hidden,isDefault,defaultReasoningEffort,const DeepCollectionEquality().hash(supportedReasoningEfforts));

@override
String toString() {
  return 'CodexModelDto(id: $id, displayName: $displayName, hidden: $hidden, isDefault: $isDefault, defaultReasoningEffort: $defaultReasoningEffort, supportedReasoningEfforts: $supportedReasoningEfforts)';
}


}

/// @nodoc
abstract mixin class $CodexModelDtoCopyWith<$Res>  {
  factory $CodexModelDtoCopyWith(CodexModelDto value, $Res Function(CodexModelDto) _then) = _$CodexModelDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? displayName, bool? hidden, bool? isDefault, String? defaultReasoningEffort,@CodexReasoningEffortsMapper() List<CodexReasoningEffortDto> supportedReasoningEfforts
});




}
/// @nodoc
class _$CodexModelDtoCopyWithImpl<$Res>
    implements $CodexModelDtoCopyWith<$Res> {
  _$CodexModelDtoCopyWithImpl(this._self, this._then);

  final CodexModelDto _self;
  final $Res Function(CodexModelDto) _then;

/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? isDefault = freezed,Object? defaultReasoningEffort = freezed,Object? supportedReasoningEfforts = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,supportedReasoningEfforts: null == supportedReasoningEfforts ? _self.supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortDto>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexModelDto implements CodexModelDto {
  const _CodexModelDto({required this.id, required this.displayName, required this.hidden, required this.isDefault, required this.defaultReasoningEffort, @CodexReasoningEffortsMapper() required final  List<CodexReasoningEffortDto> supportedReasoningEfforts}): _supportedReasoningEfforts = supportedReasoningEfforts;
  factory _CodexModelDto.fromJson(Map<String, dynamic> json) => _$CodexModelDtoFromJson(json);

@override final  String? id;
@override final  String? displayName;
@override final  bool? hidden;
@override final  bool? isDefault;
@override final  String? defaultReasoningEffort;
 final  List<CodexReasoningEffortDto> _supportedReasoningEfforts;
@override@CodexReasoningEffortsMapper() List<CodexReasoningEffortDto> get supportedReasoningEfforts {
  if (_supportedReasoningEfforts is EqualUnmodifiableListView) return _supportedReasoningEfforts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedReasoningEfforts);
}


/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelDtoCopyWith<_CodexModelDto> get copyWith => __$CodexModelDtoCopyWithImpl<_CodexModelDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexModelDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.defaultReasoningEffort, defaultReasoningEffort) || other.defaultReasoningEffort == defaultReasoningEffort)&&const DeepCollectionEquality().equals(other._supportedReasoningEfforts, _supportedReasoningEfforts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,hidden,isDefault,defaultReasoningEffort,const DeepCollectionEquality().hash(_supportedReasoningEfforts));

@override
String toString() {
  return 'CodexModelDto(id: $id, displayName: $displayName, hidden: $hidden, isDefault: $isDefault, defaultReasoningEffort: $defaultReasoningEffort, supportedReasoningEfforts: $supportedReasoningEfforts)';
}


}

/// @nodoc
abstract mixin class _$CodexModelDtoCopyWith<$Res> implements $CodexModelDtoCopyWith<$Res> {
  factory _$CodexModelDtoCopyWith(_CodexModelDto value, $Res Function(_CodexModelDto) _then) = __$CodexModelDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? displayName, bool? hidden, bool? isDefault, String? defaultReasoningEffort,@CodexReasoningEffortsMapper() List<CodexReasoningEffortDto> supportedReasoningEfforts
});




}
/// @nodoc
class __$CodexModelDtoCopyWithImpl<$Res>
    implements _$CodexModelDtoCopyWith<$Res> {
  __$CodexModelDtoCopyWithImpl(this._self, this._then);

  final _CodexModelDto _self;
  final $Res Function(_CodexModelDto) _then;

/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? isDefault = freezed,Object? defaultReasoningEffort = freezed,Object? supportedReasoningEfforts = null,}) {
  return _then(_CodexModelDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,supportedReasoningEfforts: null == supportedReasoningEfforts ? _self._supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortDto>,
  ));
}


}


/// @nodoc
mixin _$CodexReasoningEffortDto {

 String? get reasoningEffort; String? get description;
/// Create a copy of CodexReasoningEffortDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexReasoningEffortDtoCopyWith<CodexReasoningEffortDto> get copyWith => _$CodexReasoningEffortDtoCopyWithImpl<CodexReasoningEffortDto>(this as CodexReasoningEffortDto, _$identity);

  /// Serializes this CodexReasoningEffortDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexReasoningEffortDto&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,reasoningEffort,description);

@override
String toString() {
  return 'CodexReasoningEffortDto(reasoningEffort: $reasoningEffort, description: $description)';
}


}

/// @nodoc
abstract mixin class $CodexReasoningEffortDtoCopyWith<$Res>  {
  factory $CodexReasoningEffortDtoCopyWith(CodexReasoningEffortDto value, $Res Function(CodexReasoningEffortDto) _then) = _$CodexReasoningEffortDtoCopyWithImpl;
@useResult
$Res call({
 String? reasoningEffort, String? description
});




}
/// @nodoc
class _$CodexReasoningEffortDtoCopyWithImpl<$Res>
    implements $CodexReasoningEffortDtoCopyWith<$Res> {
  _$CodexReasoningEffortDtoCopyWithImpl(this._self, this._then);

  final CodexReasoningEffortDto _self;
  final $Res Function(CodexReasoningEffortDto) _then;

/// Create a copy of CodexReasoningEffortDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reasoningEffort = freezed,Object? description = freezed,}) {
  return _then(_self.copyWith(
reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexReasoningEffortDto implements CodexReasoningEffortDto {
  const _CodexReasoningEffortDto({required this.reasoningEffort, required this.description});
  factory _CodexReasoningEffortDto.fromJson(Map<String, dynamic> json) => _$CodexReasoningEffortDtoFromJson(json);

@override final  String? reasoningEffort;
@override final  String? description;

/// Create a copy of CodexReasoningEffortDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexReasoningEffortDtoCopyWith<_CodexReasoningEffortDto> get copyWith => __$CodexReasoningEffortDtoCopyWithImpl<_CodexReasoningEffortDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexReasoningEffortDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexReasoningEffortDto&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,reasoningEffort,description);

@override
String toString() {
  return 'CodexReasoningEffortDto(reasoningEffort: $reasoningEffort, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CodexReasoningEffortDtoCopyWith<$Res> implements $CodexReasoningEffortDtoCopyWith<$Res> {
  factory _$CodexReasoningEffortDtoCopyWith(_CodexReasoningEffortDto value, $Res Function(_CodexReasoningEffortDto) _then) = __$CodexReasoningEffortDtoCopyWithImpl;
@override @useResult
$Res call({
 String? reasoningEffort, String? description
});




}
/// @nodoc
class __$CodexReasoningEffortDtoCopyWithImpl<$Res>
    implements _$CodexReasoningEffortDtoCopyWith<$Res> {
  __$CodexReasoningEffortDtoCopyWithImpl(this._self, this._then);

  final _CodexReasoningEffortDto _self;
  final $Res Function(_CodexReasoningEffortDto) _then;

/// Create a copy of CodexReasoningEffortDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reasoningEffort = freezed,Object? description = freezed,}) {
  return _then(_CodexReasoningEffortDto(
reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexTextValueDto {

 String? get type; String? get text;
/// Create a copy of CodexTextValueDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTextValueDtoCopyWith<CodexTextValueDto> get copyWith => _$CodexTextValueDtoCopyWithImpl<CodexTextValueDto>(this as CodexTextValueDto, _$identity);

  /// Serializes this CodexTextValueDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTextValueDto&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'CodexTextValueDto(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexTextValueDtoCopyWith<$Res>  {
  factory $CodexTextValueDtoCopyWith(CodexTextValueDto value, $Res Function(CodexTextValueDto) _then) = _$CodexTextValueDtoCopyWithImpl;
@useResult
$Res call({
 String? type, String? text
});




}
/// @nodoc
class _$CodexTextValueDtoCopyWithImpl<$Res>
    implements $CodexTextValueDtoCopyWith<$Res> {
  _$CodexTextValueDtoCopyWithImpl(this._self, this._then);

  final CodexTextValueDto _self;
  final $Res Function(CodexTextValueDto) _then;

/// Create a copy of CodexTextValueDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexTextValueDto implements CodexTextValueDto {
  const _CodexTextValueDto({required this.type, required this.text});
  factory _CodexTextValueDto.fromJson(Map<String, dynamic> json) => _$CodexTextValueDtoFromJson(json);

@override final  String? type;
@override final  String? text;

/// Create a copy of CodexTextValueDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexTextValueDtoCopyWith<_CodexTextValueDto> get copyWith => __$CodexTextValueDtoCopyWithImpl<_CodexTextValueDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTextValueDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTextValueDto&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'CodexTextValueDto(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class _$CodexTextValueDtoCopyWith<$Res> implements $CodexTextValueDtoCopyWith<$Res> {
  factory _$CodexTextValueDtoCopyWith(_CodexTextValueDto value, $Res Function(_CodexTextValueDto) _then) = __$CodexTextValueDtoCopyWithImpl;
@override @useResult
$Res call({
 String? type, String? text
});




}
/// @nodoc
class __$CodexTextValueDtoCopyWithImpl<$Res>
    implements _$CodexTextValueDtoCopyWith<$Res> {
  __$CodexTextValueDtoCopyWithImpl(this._self, this._then);

  final _CodexTextValueDto _self;
  final $Res Function(_CodexTextValueDto) _then;

/// Create a copy of CodexTextValueDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(_CodexTextValueDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
