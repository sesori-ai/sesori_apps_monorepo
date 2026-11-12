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
  final _this = this as CodexSubAgentItemParamsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentItemParamsDto&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId)&&(identical(other.turnId, _this.turnId) || other.turnId == _this.turnId)&&(identical(other.item, _this.item) || other.item == _this.item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexSubAgentItemParamsDto;
  return Object.hash(runtimeType,_this.threadId,_this.turnId,_this.item);
}

@override
String toString() {
  final _this = this as CodexSubAgentItemParamsDto;
  return 'CodexSubAgentItemParamsDto(threadId: ${_this.threadId}, turnId: ${_this.turnId}, item: ${_this.item})';
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
int get hashCode {
    return Object.hash(runtimeType,threadId,turnId,item);
}

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

CodexSubAgentItemDto _$CodexSubAgentItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'subAgentActivity':
          return CodexSubAgentActivityItemDto.fromJson(
            json
          );
                case 'collabAgentToolCall':
          return CodexCollabAgentToolCallItemDto.fromJson(
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

class CodexSubAgentActivityItemDto implements CodexSubAgentItemDto {
  const CodexSubAgentActivityItemDto({required this.id, @JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) required this.kind, @JsonKey(fromJson: _textFromJson) required this.agentThreadId, @JsonKey(fromJson: _textFromJson) required this.agentPath, @JsonKey(fromJson: _textFromJson) required this.model, @JsonKey(fromJson: _textFromJson) required this.reasoningEffort,  String? $type}): $type = $type ?? 'subAgentActivity';
  factory CodexSubAgentActivityItemDto.fromJson(Map<String, dynamic> json) => _$CodexSubAgentActivityItemDtoFromJson(json);

 final  String? id;
@JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) final  CodexSubAgentActivityKind kind;
@JsonKey(fromJson: _textFromJson) final  String? agentThreadId;
@JsonKey(fromJson: _textFromJson) final  String? agentPath;
/// Resolved at sub-agent creation; only `started` activities carry them,
/// and not before codex-cli 0.167.
@JsonKey(fromJson: _textFromJson) final  String? model;
@JsonKey(fromJson: _textFromJson) final  String? reasoningEffort;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSubAgentActivityItemDtoCopyWith<CodexSubAgentActivityItemDto> get copyWith => _$CodexSubAgentActivityItemDtoCopyWithImpl<CodexSubAgentActivityItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSubAgentActivityItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.agentThreadId, agentThreadId) || other.agentThreadId == agentThreadId)&&(identical(other.agentPath, agentPath) || other.agentPath == agentPath)&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,agentThreadId,agentPath,model,reasoningEffort);
}

@override
String toString() {
    return 'CodexSubAgentItemDto.subAgentActivity(id: $id, kind: $kind, agentThreadId: $agentThreadId, agentPath: $agentPath, model: $model, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class $CodexSubAgentActivityItemDtoCopyWith<$Res> implements $CodexSubAgentItemDtoCopyWith<$Res> {
  factory $CodexSubAgentActivityItemDtoCopyWith(CodexSubAgentActivityItemDto value, $Res Function(CodexSubAgentActivityItemDto) _then) = _$CodexSubAgentActivityItemDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(unknownEnumValue: CodexSubAgentActivityKind.unknown, defaultValue: CodexSubAgentActivityKind.unknown) CodexSubAgentActivityKind kind,@JsonKey(fromJson: _textFromJson) String? agentThreadId,@JsonKey(fromJson: _textFromJson) String? agentPath,@JsonKey(fromJson: _textFromJson) String? model,@JsonKey(fromJson: _textFromJson) String? reasoningEffort
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
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? kind = null,Object? agentThreadId = freezed,Object? agentPath = freezed,Object? model = freezed,Object? reasoningEffort = freezed,}) {
  return _then(CodexSubAgentActivityItemDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexSubAgentActivityKind,agentThreadId: freezed == agentThreadId ? _self.agentThreadId : agentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentPath: freezed == agentPath ? _self.agentPath : agentPath // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexCollabAgentToolCallItemDto implements CodexSubAgentItemDto {
  const CodexCollabAgentToolCallItemDto({required this.id, @JsonKey(fromJson: _textFromJson) required this.tool,  List<String> receiverThreadIds = const <String>[], @JsonKey(fromJson: _textFromJson) required this.model, @JsonKey(fromJson: _textFromJson) required this.reasoningEffort,  String? $type}): _receiverThreadIds = receiverThreadIds,$type = $type ?? 'collabAgentToolCall';
  factory CodexCollabAgentToolCallItemDto.fromJson(Map<String, dynamic> json) => _$CodexCollabAgentToolCallItemDtoFromJson(json);

 final  String? id;
@JsonKey(fromJson: _textFromJson) final  String? tool;
 final  List<String> _receiverThreadIds;
@JsonKey() List<String> get receiverThreadIds {
  if (_receiverThreadIds is EqualUnmodifiableListView) return _receiverThreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_receiverThreadIds);
}

@JsonKey(fromJson: _textFromJson) final  String? model;
@JsonKey(fromJson: _textFromJson) final  String? reasoningEffort;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCollabAgentToolCallItemDtoCopyWith<CodexCollabAgentToolCallItemDto> get copyWith => _$CodexCollabAgentToolCallItemDtoCopyWithImpl<CodexCollabAgentToolCallItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCollabAgentToolCallItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&const DeepCollectionEquality().equals(other.receiverThreadIds, _receiverThreadIds)&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,tool,const DeepCollectionEquality().hash(_receiverThreadIds),model,reasoningEffort);
}

@override
String toString() {
    return 'CodexSubAgentItemDto.collabAgentToolCall(id: $id, tool: $tool, receiverThreadIds: $receiverThreadIds, model: $model, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class $CodexCollabAgentToolCallItemDtoCopyWith<$Res> implements $CodexSubAgentItemDtoCopyWith<$Res> {
  factory $CodexCollabAgentToolCallItemDtoCopyWith(CodexCollabAgentToolCallItemDto value, $Res Function(CodexCollabAgentToolCallItemDto) _then) = _$CodexCollabAgentToolCallItemDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(fromJson: _textFromJson) String? tool, List<String> receiverThreadIds,@JsonKey(fromJson: _textFromJson) String? model,@JsonKey(fromJson: _textFromJson) String? reasoningEffort
});




}
/// @nodoc
class _$CodexCollabAgentToolCallItemDtoCopyWithImpl<$Res>
    implements $CodexCollabAgentToolCallItemDtoCopyWith<$Res> {
  _$CodexCollabAgentToolCallItemDtoCopyWithImpl(this._self, this._then);

  final CodexCollabAgentToolCallItemDto _self;
  final $Res Function(CodexCollabAgentToolCallItemDto) _then;

/// Create a copy of CodexSubAgentItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? tool = freezed,Object? receiverThreadIds = null,Object? model = freezed,Object? reasoningEffort = freezed,}) {
  return _then(CodexCollabAgentToolCallItemDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,receiverThreadIds: null == receiverThreadIds ? _self._receiverThreadIds : receiverThreadIds // ignore: cast_nullable_to_non_nullable
as List<String>,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
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
