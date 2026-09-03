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
@JsonSerializable(createToJson: false)

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
mixin _$CodexCollabAgentStateDto {

@JsonKey(unknownEnumValue: CodexCollabAgentStatus.unknown, defaultValue: CodexCollabAgentStatus.unknown) CodexCollabAgentStatus get status;@JsonKey(fromJson: _textFromJson) String? get message;
/// Create a copy of CodexCollabAgentStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCollabAgentStateDtoCopyWith<CodexCollabAgentStateDto> get copyWith => _$CodexCollabAgentStateDtoCopyWithImpl<CodexCollabAgentStateDto>(this as CodexCollabAgentStateDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCollabAgentStateDto&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,message);

@override
String toString() {
  return 'CodexCollabAgentStateDto(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class $CodexCollabAgentStateDtoCopyWith<$Res>  {
  factory $CodexCollabAgentStateDtoCopyWith(CodexCollabAgentStateDto value, $Res Function(CodexCollabAgentStateDto) _then) = _$CodexCollabAgentStateDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexCollabAgentStatus.unknown, defaultValue: CodexCollabAgentStatus.unknown) CodexCollabAgentStatus status,@JsonKey(fromJson: _textFromJson) String? message
});




}
/// @nodoc
class _$CodexCollabAgentStateDtoCopyWithImpl<$Res>
    implements $CodexCollabAgentStateDtoCopyWith<$Res> {
  _$CodexCollabAgentStateDtoCopyWithImpl(this._self, this._then);

  final CodexCollabAgentStateDto _self;
  final $Res Function(CodexCollabAgentStateDto) _then;

/// Create a copy of CodexCollabAgentStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? message = freezed,}) {
  return _then(CodexCollabAgentStateDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCollabAgentStatus,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexCollabAgentStateDto implements CodexCollabAgentStateDto {
  const _CodexCollabAgentStateDto({@JsonKey(unknownEnumValue: CodexCollabAgentStatus.unknown, defaultValue: CodexCollabAgentStatus.unknown) required this.status, @JsonKey(fromJson: _textFromJson) required this.message});
  factory _CodexCollabAgentStateDto.fromJson(Map<String, dynamic> json) => _$CodexCollabAgentStateDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexCollabAgentStatus.unknown, defaultValue: CodexCollabAgentStatus.unknown) final  CodexCollabAgentStatus status;
@override@JsonKey(fromJson: _textFromJson) final  String? message;

/// Create a copy of CodexCollabAgentStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexCollabAgentStateDtoCopyWith<_CodexCollabAgentStateDto> get copyWith => __$CodexCollabAgentStateDtoCopyWithImpl<_CodexCollabAgentStateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexCollabAgentStateDto&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,message);

@override
String toString() {
  return 'CodexCollabAgentStateDto(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class _$CodexCollabAgentStateDtoCopyWith<$Res> implements $CodexCollabAgentStateDtoCopyWith<$Res> {
  factory _$CodexCollabAgentStateDtoCopyWith(_CodexCollabAgentStateDto value, $Res Function(_CodexCollabAgentStateDto) _then) = __$CodexCollabAgentStateDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexCollabAgentStatus.unknown, defaultValue: CodexCollabAgentStatus.unknown) CodexCollabAgentStatus status,@JsonKey(fromJson: _textFromJson) String? message
});




}
/// @nodoc
class __$CodexCollabAgentStateDtoCopyWithImpl<$Res>
    implements _$CodexCollabAgentStateDtoCopyWith<$Res> {
  __$CodexCollabAgentStateDtoCopyWithImpl(this._self, this._then);

  final _CodexCollabAgentStateDto _self;
  final $Res Function(_CodexCollabAgentStateDto) _then;

/// Create a copy of CodexCollabAgentStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? message = freezed,}) {
  return _then(_CodexCollabAgentStateDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCollabAgentStatus,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

CodexSubAgentItemDto _$CodexSubAgentItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'collabToolCall':
          return CodexCollabToolCallItemDto.fromJson(
            json
          );
                case 'subAgentActivity':
          return CodexSubAgentActivityItemDto.fromJson(
            json
          );
        
          default:
            return CodexUnknownSubAgentItemDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexSubAgentItemDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexSubAgentItemDto()';
}


}

/// @nodoc
class $CodexSubAgentItemDtoCopyWith<$Res>  {
$CodexSubAgentItemDtoCopyWith(CodexSubAgentItemDto _, $Res Function(CodexSubAgentItemDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexCollabToolCallItemDto implements CodexSubAgentItemDto {
  const CodexCollabToolCallItemDto({required this.id, @JsonKey(unknownEnumValue: CodexCollabTool.unknown, defaultValue: CodexCollabTool.unknown) required this.tool, @JsonKey(unknownEnumValue: CodexCollabItemStatus.unknown, defaultValue: CodexCollabItemStatus.unknown) required this.status, @JsonKey(fromJson: _textFromJson) required this.senderThreadId, @JsonKey(fromJson: _threadIdListFromJson) required  List<String> receiverThreadIds, @JsonKey(fromJson: _textFromJson) required this.receiverThreadId, @JsonKey(fromJson: _textFromJson) required this.newThreadId, @JsonKey(fromJson: _textFromJson) required this.prompt, @JsonKey(defaultValue: <String, CodexCollabAgentStateDto>{}) required  Map<String, CodexCollabAgentStateDto> agentsStates,  String? $type}): _receiverThreadIds = receiverThreadIds,_agentsStates = agentsStates,$type = $type ?? 'collabToolCall';
  factory CodexCollabToolCallItemDto.fromJson(Map<String, dynamic> json) => _$CodexCollabToolCallItemDtoFromJson(json);

 final  String? id;
@JsonKey(unknownEnumValue: CodexCollabTool.unknown, defaultValue: CodexCollabTool.unknown) final  CodexCollabTool tool;
@JsonKey(unknownEnumValue: CodexCollabItemStatus.unknown, defaultValue: CodexCollabItemStatus.unknown) final  CodexCollabItemStatus status;
@JsonKey(fromJson: _textFromJson) final  String? senderThreadId;
 final  List<String> _receiverThreadIds;
@JsonKey(fromJson: _threadIdListFromJson) List<String> get receiverThreadIds {
  if (_receiverThreadIds is EqualUnmodifiableListView) return _receiverThreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_receiverThreadIds);
}

@JsonKey(fromJson: _textFromJson) final  String? receiverThreadId;
@JsonKey(fromJson: _textFromJson) final  String? newThreadId;
@JsonKey(fromJson: _textFromJson) final  String? prompt;
 final  Map<String, CodexCollabAgentStateDto> _agentsStates;
@JsonKey(defaultValue: <String, CodexCollabAgentStateDto>{}) Map<String, CodexCollabAgentStateDto> get agentsStates {
  if (_agentsStates is EqualUnmodifiableMapView) return _agentsStates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_agentsStates);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCollabToolCallItemDtoCopyWith<CodexCollabToolCallItemDto> get copyWith => _$CodexCollabToolCallItemDtoCopyWithImpl<CodexCollabToolCallItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCollabToolCallItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&(identical(other.senderThreadId, senderThreadId) || other.senderThreadId == senderThreadId)&&const DeepCollectionEquality().equals(other._receiverThreadIds, _receiverThreadIds)&&(identical(other.receiverThreadId, receiverThreadId) || other.receiverThreadId == receiverThreadId)&&(identical(other.newThreadId, newThreadId) || other.newThreadId == newThreadId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other._agentsStates, _agentsStates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tool,status,senderThreadId,const DeepCollectionEquality().hash(_receiverThreadIds),receiverThreadId,newThreadId,prompt,const DeepCollectionEquality().hash(_agentsStates));

@override
String toString() {
  return 'CodexSubAgentItemDto.collabToolCall(id: $id, tool: $tool, status: $status, senderThreadId: $senderThreadId, receiverThreadIds: $receiverThreadIds, receiverThreadId: $receiverThreadId, newThreadId: $newThreadId, prompt: $prompt, agentsStates: $agentsStates)';
}


}

/// @nodoc
abstract mixin class $CodexCollabToolCallItemDtoCopyWith<$Res> implements $CodexSubAgentItemDtoCopyWith<$Res> {
  factory $CodexCollabToolCallItemDtoCopyWith(CodexCollabToolCallItemDto value, $Res Function(CodexCollabToolCallItemDto) _then) = _$CodexCollabToolCallItemDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(unknownEnumValue: CodexCollabTool.unknown, defaultValue: CodexCollabTool.unknown) CodexCollabTool tool,@JsonKey(unknownEnumValue: CodexCollabItemStatus.unknown, defaultValue: CodexCollabItemStatus.unknown) CodexCollabItemStatus status,@JsonKey(fromJson: _textFromJson) String? senderThreadId,@JsonKey(fromJson: _threadIdListFromJson) List<String> receiverThreadIds,@JsonKey(fromJson: _textFromJson) String? receiverThreadId,@JsonKey(fromJson: _textFromJson) String? newThreadId,@JsonKey(fromJson: _textFromJson) String? prompt,@JsonKey(defaultValue: <String, CodexCollabAgentStateDto>{}) Map<String, CodexCollabAgentStateDto> agentsStates
});




}
/// @nodoc
class _$CodexCollabToolCallItemDtoCopyWithImpl<$Res>
    implements $CodexCollabToolCallItemDtoCopyWith<$Res> {
  _$CodexCollabToolCallItemDtoCopyWithImpl(this._self, this._then);

  final CodexCollabToolCallItemDto _self;
  final $Res Function(CodexCollabToolCallItemDto) _then;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? tool = null,Object? status = null,Object? senderThreadId = freezed,Object? receiverThreadIds = null,Object? receiverThreadId = freezed,Object? newThreadId = freezed,Object? prompt = freezed,Object? agentsStates = null,}) {
  return _then(CodexCollabToolCallItemDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as CodexCollabTool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCollabItemStatus,senderThreadId: freezed == senderThreadId ? _self.senderThreadId : senderThreadId // ignore: cast_nullable_to_non_nullable
as String?,receiverThreadIds: null == receiverThreadIds ? _self._receiverThreadIds : receiverThreadIds // ignore: cast_nullable_to_non_nullable
as List<String>,receiverThreadId: freezed == receiverThreadId ? _self.receiverThreadId : receiverThreadId // ignore: cast_nullable_to_non_nullable
as String?,newThreadId: freezed == newThreadId ? _self.newThreadId : newThreadId // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,agentsStates: null == agentsStates ? _self._agentsStates : agentsStates // ignore: cast_nullable_to_non_nullable
as Map<String, CodexCollabAgentStateDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexSubAgentActivityItemDto implements CodexSubAgentItemDto {
  const CodexSubAgentActivityItemDto({required this.id, @JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) required this.kind, @JsonKey(fromJson: _textFromJson) required this.agentThreadId, @JsonKey(fromJson: _textFromJson) required this.agentPath,  String? $type}): $type = $type ?? 'subAgentActivity';
  factory CodexSubAgentActivityItemDto.fromJson(Map<String, dynamic> json) => _$CodexSubAgentActivityItemDtoFromJson(json);

 final  String? id;
@JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) final  CodexSubAgentActivityKind kind;
@JsonKey(fromJson: _textFromJson) final  String? agentThreadId;
@JsonKey(fromJson: _textFromJson) final  String? agentPath;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSubAgentActivityItemDtoCopyWith<CodexSubAgentActivityItemDto> get copyWith => _$CodexSubAgentActivityItemDtoCopyWithImpl<CodexSubAgentActivityItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentActivityItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.agentThreadId, agentThreadId) || other.agentThreadId == agentThreadId)&&(identical(other.agentPath, agentPath) || other.agentPath == agentPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,agentThreadId,agentPath);

@override
String toString() {
  return 'CodexSubAgentItemDto.subAgentActivity(id: $id, kind: $kind, agentThreadId: $agentThreadId, agentPath: $agentPath)';
}


}

/// @nodoc
abstract mixin class $CodexSubAgentActivityItemDtoCopyWith<$Res> implements $CodexSubAgentItemDtoCopyWith<$Res> {
  factory $CodexSubAgentActivityItemDtoCopyWith(CodexSubAgentActivityItemDto value, $Res Function(CodexSubAgentActivityItemDto) _then) = _$CodexSubAgentActivityItemDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) CodexSubAgentActivityKind kind,@JsonKey(fromJson: _textFromJson) String? agentThreadId,@JsonKey(fromJson: _textFromJson) String? agentPath
});




}
/// @nodoc
class _$CodexSubAgentActivityItemDtoCopyWithImpl<$Res>
    implements $CodexSubAgentActivityItemDtoCopyWith<$Res> {
  _$CodexSubAgentActivityItemDtoCopyWithImpl(this._self, this._then);

  final CodexSubAgentActivityItemDto _self;
  final $Res Function(CodexSubAgentActivityItemDto) _then;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? kind = null,Object? agentThreadId = freezed,Object? agentPath = freezed,}) {
  return _then(CodexSubAgentActivityItemDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexSubAgentActivityKind,agentThreadId: freezed == agentThreadId ? _self.agentThreadId : agentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentPath: freezed == agentPath ? _self.agentPath : agentPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexUnknownSubAgentItemDto implements CodexSubAgentItemDto {
  const CodexUnknownSubAgentItemDto({ String? $type}): $type = $type ?? 'unknown';
  factory CodexUnknownSubAgentItemDto.fromJson(Map<String, dynamic> json) => _$CodexUnknownSubAgentItemDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUnknownSubAgentItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexSubAgentItemDto.unknown()';
}


}




// dart format on
