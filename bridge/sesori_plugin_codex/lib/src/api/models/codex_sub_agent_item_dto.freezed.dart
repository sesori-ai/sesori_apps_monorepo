// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_sub_agent_item_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexSubAgentItemParamsDto {

 String? get threadId; String? get turnId; CodexSubAgentItemDto get item;
/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSubAgentItemParamsDtoCopyWith<CodexSubAgentItemParamsDto> get copyWith => _$CodexSubAgentItemParamsDtoCopyWithImpl<CodexSubAgentItemParamsDto>(this as CodexSubAgentItemParamsDto, _$identity);

  /// Serializes this CodexSubAgentItemParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentItemParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexSubAgentItemParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class $CodexSubAgentItemParamsDtoCopyWith<$Res>  {
  factory $CodexSubAgentItemParamsDtoCopyWith(CodexSubAgentItemParamsDto value, $Res Function(CodexSubAgentItemParamsDto) _then) = _$CodexSubAgentItemParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? threadId, String? turnId, CodexSubAgentItemDto item
});


$CodexSubAgentItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class _$CodexSubAgentItemParamsDtoCopyWithImpl<$Res>
    implements $CodexSubAgentItemParamsDtoCopyWith<$Res> {
  _$CodexSubAgentItemParamsDtoCopyWithImpl(this._self, this._then);

  final CodexSubAgentItemParamsDto _self;
  final $Res Function(CodexSubAgentItemParamsDto) _then;

/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(CodexSubAgentItemParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexSubAgentItemDto,
  ));
}
/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexSubAgentItemDtoCopyWith<$Res> get item {
  
  return $CodexSubAgentItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexSubAgentItemParamsDto implements CodexSubAgentItemParamsDto {
  const _CodexSubAgentItemParamsDto({required this.threadId, required this.turnId, required this.item});
  factory _CodexSubAgentItemParamsDto.fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemParamsDtoFromJson(json);

@override final  String? threadId;
@override final  String? turnId;
@override final  CodexSubAgentItemDto item;

/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSubAgentItemParamsDtoCopyWith<_CodexSubAgentItemParamsDto> get copyWith => __$CodexSubAgentItemParamsDtoCopyWithImpl<_CodexSubAgentItemParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexSubAgentItemParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSubAgentItemParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexSubAgentItemParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class _$CodexSubAgentItemParamsDtoCopyWith<$Res> implements $CodexSubAgentItemParamsDtoCopyWith<$Res> {
  factory _$CodexSubAgentItemParamsDtoCopyWith(_CodexSubAgentItemParamsDto value, $Res Function(_CodexSubAgentItemParamsDto) _then) = __$CodexSubAgentItemParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? threadId, String? turnId, CodexSubAgentItemDto item
});


@override $CodexSubAgentItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class __$CodexSubAgentItemParamsDtoCopyWithImpl<$Res>
    implements _$CodexSubAgentItemParamsDtoCopyWith<$Res> {
  __$CodexSubAgentItemParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexSubAgentItemParamsDto _self;
  final $Res Function(_CodexSubAgentItemParamsDto) _then;

/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(_CodexSubAgentItemParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexSubAgentItemDto,
  ));
}

/// Create a copy of CodexSubAgentItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexSubAgentItemDtoCopyWith<$Res> get item {
  
  return $CodexSubAgentItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$CodexSubAgentItemDto {

@JsonKey(unknownEnumValue: CodexSubAgentItemType.unknown, defaultValue: CodexSubAgentItemType.unknown) CodexSubAgentItemType get type; String? get id;@JsonKey(fromJson: _collabToolFromJson) CodexCollabTool get tool;@JsonKey(fromJson: _collabItemStatusFromJson) CodexCollabItemStatus get status;@JsonKey(fromJson: _textFromJson) String? get senderThreadId;@JsonKey(fromJson: _threadIdListFromJson) List<String> get receiverThreadIds;@JsonKey(fromJson: _textFromJson) String? get receiverThreadId;@JsonKey(fromJson: _textFromJson) String? get newThreadId;@JsonKey(fromJson: _textFromJson) String? get prompt;@CodexCollabAgentStatesConverter() Map<String, CodexCollabAgentStatus> get agentsStates;@JsonKey(fromJson: _activityKindFromJson) CodexSubAgentActivityKind get kind;@JsonKey(fromJson: _textFromJson) String? get agentThreadId;@JsonKey(fromJson: _textFromJson) String? get agentPath;
/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSubAgentItemDtoCopyWith<CodexSubAgentItemDto> get copyWith => _$CodexSubAgentItemDtoCopyWithImpl<CodexSubAgentItemDto>(this as CodexSubAgentItemDto, _$identity);

  /// Serializes this CodexSubAgentItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&(identical(other.senderThreadId, senderThreadId) || other.senderThreadId == senderThreadId)&&const DeepCollectionEquality().equals(other.receiverThreadIds, receiverThreadIds)&&(identical(other.receiverThreadId, receiverThreadId) || other.receiverThreadId == receiverThreadId)&&(identical(other.newThreadId, newThreadId) || other.newThreadId == newThreadId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other.agentsStates, agentsStates)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.agentThreadId, agentThreadId) || other.agentThreadId == agentThreadId)&&(identical(other.agentPath, agentPath) || other.agentPath == agentPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,tool,status,senderThreadId,const DeepCollectionEquality().hash(receiverThreadIds),receiverThreadId,newThreadId,prompt,const DeepCollectionEquality().hash(agentsStates),kind,agentThreadId,agentPath);

@override
String toString() {
  return 'CodexSubAgentItemDto(type: $type, id: $id, tool: $tool, status: $status, senderThreadId: $senderThreadId, receiverThreadIds: $receiverThreadIds, receiverThreadId: $receiverThreadId, newThreadId: $newThreadId, prompt: $prompt, agentsStates: $agentsStates, kind: $kind, agentThreadId: $agentThreadId, agentPath: $agentPath)';
}


}

/// @nodoc
abstract mixin class $CodexSubAgentItemDtoCopyWith<$Res>  {
  factory $CodexSubAgentItemDtoCopyWith(CodexSubAgentItemDto value, $Res Function(CodexSubAgentItemDto) _then) = _$CodexSubAgentItemDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexSubAgentItemType.unknown, defaultValue: CodexSubAgentItemType.unknown) CodexSubAgentItemType type, String? id,@JsonKey(fromJson: _collabToolFromJson) CodexCollabTool tool,@JsonKey(fromJson: _collabItemStatusFromJson) CodexCollabItemStatus status,@JsonKey(fromJson: _textFromJson) String? senderThreadId,@JsonKey(fromJson: _threadIdListFromJson) List<String> receiverThreadIds,@JsonKey(fromJson: _textFromJson) String? receiverThreadId,@JsonKey(fromJson: _textFromJson) String? newThreadId,@JsonKey(fromJson: _textFromJson) String? prompt,@CodexCollabAgentStatesConverter() Map<String, CodexCollabAgentStatus> agentsStates,@JsonKey(fromJson: _activityKindFromJson) CodexSubAgentActivityKind kind,@JsonKey(fromJson: _textFromJson) String? agentThreadId,@JsonKey(fromJson: _textFromJson) String? agentPath
});




}
/// @nodoc
class _$CodexSubAgentItemDtoCopyWithImpl<$Res>
    implements $CodexSubAgentItemDtoCopyWith<$Res> {
  _$CodexSubAgentItemDtoCopyWithImpl(this._self, this._then);

  final CodexSubAgentItemDto _self;
  final $Res Function(CodexSubAgentItemDto) _then;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = freezed,Object? tool = null,Object? status = null,Object? senderThreadId = freezed,Object? receiverThreadIds = null,Object? receiverThreadId = freezed,Object? newThreadId = freezed,Object? prompt = freezed,Object? agentsStates = null,Object? kind = null,Object? agentThreadId = freezed,Object? agentPath = freezed,}) {
  return _then(CodexSubAgentItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexSubAgentItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as CodexCollabTool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCollabItemStatus,senderThreadId: freezed == senderThreadId ? _self.senderThreadId : senderThreadId // ignore: cast_nullable_to_non_nullable
as String?,receiverThreadIds: null == receiverThreadIds ? _self.receiverThreadIds : receiverThreadIds // ignore: cast_nullable_to_non_nullable
as List<String>,receiverThreadId: freezed == receiverThreadId ? _self.receiverThreadId : receiverThreadId // ignore: cast_nullable_to_non_nullable
as String?,newThreadId: freezed == newThreadId ? _self.newThreadId : newThreadId // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,agentsStates: null == agentsStates ? _self.agentsStates : agentsStates // ignore: cast_nullable_to_non_nullable
as Map<String, CodexCollabAgentStatus>,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexSubAgentActivityKind,agentThreadId: freezed == agentThreadId ? _self.agentThreadId : agentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentPath: freezed == agentPath ? _self.agentPath : agentPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexSubAgentItemDto implements CodexSubAgentItemDto {
  const _CodexSubAgentItemDto({@JsonKey(unknownEnumValue: CodexSubAgentItemType.unknown, defaultValue: CodexSubAgentItemType.unknown) required this.type, required this.id, @JsonKey(fromJson: _collabToolFromJson) required this.tool, @JsonKey(fromJson: _collabItemStatusFromJson) required this.status, @JsonKey(fromJson: _textFromJson) required this.senderThreadId, @JsonKey(fromJson: _threadIdListFromJson) required  List<String> receiverThreadIds, @JsonKey(fromJson: _textFromJson) required this.receiverThreadId, @JsonKey(fromJson: _textFromJson) required this.newThreadId, @JsonKey(fromJson: _textFromJson) required this.prompt, @CodexCollabAgentStatesConverter() required  Map<String, CodexCollabAgentStatus> agentsStates, @JsonKey(fromJson: _activityKindFromJson) required this.kind, @JsonKey(fromJson: _textFromJson) required this.agentThreadId, @JsonKey(fromJson: _textFromJson) required this.agentPath}): _receiverThreadIds = receiverThreadIds,_agentsStates = agentsStates;
  factory _CodexSubAgentItemDto.fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexSubAgentItemType.unknown, defaultValue: CodexSubAgentItemType.unknown) final  CodexSubAgentItemType type;
@override final  String? id;
@override@JsonKey(fromJson: _collabToolFromJson) final  CodexCollabTool tool;
@override@JsonKey(fromJson: _collabItemStatusFromJson) final  CodexCollabItemStatus status;
@override@JsonKey(fromJson: _textFromJson) final  String? senderThreadId;
 final  List<String> _receiverThreadIds;
@override@JsonKey(fromJson: _threadIdListFromJson) List<String> get receiverThreadIds {
  if (_receiverThreadIds is EqualUnmodifiableListView) return _receiverThreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_receiverThreadIds);
}

@override@JsonKey(fromJson: _textFromJson) final  String? receiverThreadId;
@override@JsonKey(fromJson: _textFromJson) final  String? newThreadId;
@override@JsonKey(fromJson: _textFromJson) final  String? prompt;
 final  Map<String, CodexCollabAgentStatus> _agentsStates;
@override@CodexCollabAgentStatesConverter() Map<String, CodexCollabAgentStatus> get agentsStates {
  if (_agentsStates is EqualUnmodifiableMapView) return _agentsStates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_agentsStates);
}

@override@JsonKey(fromJson: _activityKindFromJson) final  CodexSubAgentActivityKind kind;
@override@JsonKey(fromJson: _textFromJson) final  String? agentThreadId;
@override@JsonKey(fromJson: _textFromJson) final  String? agentPath;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSubAgentItemDtoCopyWith<_CodexSubAgentItemDto> get copyWith => __$CodexSubAgentItemDtoCopyWithImpl<_CodexSubAgentItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexSubAgentItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSubAgentItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&(identical(other.senderThreadId, senderThreadId) || other.senderThreadId == senderThreadId)&&const DeepCollectionEquality().equals(other._receiverThreadIds, _receiverThreadIds)&&(identical(other.receiverThreadId, receiverThreadId) || other.receiverThreadId == receiverThreadId)&&(identical(other.newThreadId, newThreadId) || other.newThreadId == newThreadId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other._agentsStates, _agentsStates)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.agentThreadId, agentThreadId) || other.agentThreadId == agentThreadId)&&(identical(other.agentPath, agentPath) || other.agentPath == agentPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,tool,status,senderThreadId,const DeepCollectionEquality().hash(_receiverThreadIds),receiverThreadId,newThreadId,prompt,const DeepCollectionEquality().hash(_agentsStates),kind,agentThreadId,agentPath);

@override
String toString() {
  return 'CodexSubAgentItemDto(type: $type, id: $id, tool: $tool, status: $status, senderThreadId: $senderThreadId, receiverThreadIds: $receiverThreadIds, receiverThreadId: $receiverThreadId, newThreadId: $newThreadId, prompt: $prompt, agentsStates: $agentsStates, kind: $kind, agentThreadId: $agentThreadId, agentPath: $agentPath)';
}


}

/// @nodoc
abstract mixin class _$CodexSubAgentItemDtoCopyWith<$Res> implements $CodexSubAgentItemDtoCopyWith<$Res> {
  factory _$CodexSubAgentItemDtoCopyWith(_CodexSubAgentItemDto value, $Res Function(_CodexSubAgentItemDto) _then) = __$CodexSubAgentItemDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexSubAgentItemType.unknown, defaultValue: CodexSubAgentItemType.unknown) CodexSubAgentItemType type, String? id,@JsonKey(fromJson: _collabToolFromJson) CodexCollabTool tool,@JsonKey(fromJson: _collabItemStatusFromJson) CodexCollabItemStatus status,@JsonKey(fromJson: _textFromJson) String? senderThreadId,@JsonKey(fromJson: _threadIdListFromJson) List<String> receiverThreadIds,@JsonKey(fromJson: _textFromJson) String? receiverThreadId,@JsonKey(fromJson: _textFromJson) String? newThreadId,@JsonKey(fromJson: _textFromJson) String? prompt,@CodexCollabAgentStatesConverter() Map<String, CodexCollabAgentStatus> agentsStates,@JsonKey(fromJson: _activityKindFromJson) CodexSubAgentActivityKind kind,@JsonKey(fromJson: _textFromJson) String? agentThreadId,@JsonKey(fromJson: _textFromJson) String? agentPath
});




}
/// @nodoc
class __$CodexSubAgentItemDtoCopyWithImpl<$Res>
    implements _$CodexSubAgentItemDtoCopyWith<$Res> {
  __$CodexSubAgentItemDtoCopyWithImpl(this._self, this._then);

  final _CodexSubAgentItemDto _self;
  final $Res Function(_CodexSubAgentItemDto) _then;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = freezed,Object? tool = null,Object? status = null,Object? senderThreadId = freezed,Object? receiverThreadIds = null,Object? receiverThreadId = freezed,Object? newThreadId = freezed,Object? prompt = freezed,Object? agentsStates = null,Object? kind = null,Object? agentThreadId = freezed,Object? agentPath = freezed,}) {
  return _then(_CodexSubAgentItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexSubAgentItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as CodexCollabTool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCollabItemStatus,senderThreadId: freezed == senderThreadId ? _self.senderThreadId : senderThreadId // ignore: cast_nullable_to_non_nullable
as String?,receiverThreadIds: null == receiverThreadIds ? _self._receiverThreadIds : receiverThreadIds // ignore: cast_nullable_to_non_nullable
as List<String>,receiverThreadId: freezed == receiverThreadId ? _self.receiverThreadId : receiverThreadId // ignore: cast_nullable_to_non_nullable
as String?,newThreadId: freezed == newThreadId ? _self.newThreadId : newThreadId // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,agentsStates: null == agentsStates ? _self._agentsStates : agentsStates // ignore: cast_nullable_to_non_nullable
as Map<String, CodexCollabAgentStatus>,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexSubAgentActivityKind,agentThreadId: freezed == agentThreadId ? _self.agentThreadId : agentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentPath: freezed == agentPath ? _self.agentPath : agentPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
