// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cursor_subagent_update_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
CursorSubagentUpdateDto _$CursorSubagentUpdateDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['sessionUpdate']) {
                  case 'subagent_spawned':
          return CursorSubagentSpawnedDto.fromJson(
            json
          );
                case 'subagent_state_update':
          return CursorSubagentStateUpdateDto.fromJson(
            json
          );
        
          default:
            return CursorSubagentUpdateUnknownDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CursorSubagentUpdateDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentUpdateDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CursorSubagentUpdateDto()';
}


}

/// @nodoc
class $CursorSubagentUpdateDtoCopyWith<$Res>  {
$CursorSubagentUpdateDtoCopyWith(CursorSubagentUpdateDto _, $Res Function(CursorSubagentUpdateDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CursorSubagentSpawnedDto implements CursorSubagentUpdateDto {
  const CursorSubagentSpawnedDto({required this.subagentSessionId, required this.name, required this.task, @JsonKey(name: "_meta") required this.meta,  String? $type}): $type = $type ?? 'subagent_spawned';
  factory CursorSubagentSpawnedDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentSpawnedDtoFromJson(json);

 final  String subagentSessionId;
/// The sub-agent type, or Cursor's generic `subagent`.
 final  String? name;
/// The task title; Cursor sends an empty string when it has none.
 final  String? task;
@JsonKey(name: "_meta") final  CursorSubagentMetaDto? meta;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of CursorSubagentUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorSubagentSpawnedDtoCopyWith<CursorSubagentSpawnedDto> get copyWith => _$CursorSubagentSpawnedDtoCopyWithImpl<CursorSubagentSpawnedDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentSpawnedDto&&(identical(other.subagentSessionId, subagentSessionId) || other.subagentSessionId == subagentSessionId)&&(identical(other.name, name) || other.name == name)&&(identical(other.task, task) || other.task == task)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,subagentSessionId,name,task,meta);
}

@override
String toString() {
    return 'CursorSubagentUpdateDto.subagentSpawned(subagentSessionId: $subagentSessionId, name: $name, task: $task, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $CursorSubagentSpawnedDtoCopyWith<$Res> implements $CursorSubagentUpdateDtoCopyWith<$Res> {
  factory $CursorSubagentSpawnedDtoCopyWith(CursorSubagentSpawnedDto value, $Res Function(CursorSubagentSpawnedDto) _then) = _$CursorSubagentSpawnedDtoCopyWithImpl;
@useResult
$Res call({
 String subagentSessionId, String? name, String? task,@JsonKey(name: "_meta") CursorSubagentMetaDto? meta
});


$CursorSubagentMetaDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class _$CursorSubagentSpawnedDtoCopyWithImpl<$Res>
    implements $CursorSubagentSpawnedDtoCopyWith<$Res> {
  _$CursorSubagentSpawnedDtoCopyWithImpl(this._self, this._then);

  final CursorSubagentSpawnedDto _self;
  final $Res Function(CursorSubagentSpawnedDto) _then;

/// Create a copy of CursorSubagentUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? subagentSessionId = null,Object? name = freezed,Object? task = freezed,Object? meta = freezed,}) {
  return _then(CursorSubagentSpawnedDto(
subagentSessionId: null == subagentSessionId ? _self.subagentSessionId : subagentSessionId // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,task: freezed == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as String?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as CursorSubagentMetaDto?,
  ));
}

/// Create a copy of CursorSubagentUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $CursorSubagentMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class CursorSubagentStateUpdateDto implements CursorSubagentUpdateDto {
  const CursorSubagentStateUpdateDto({required this.subagentSessionId, @JsonKey(unknownEnumValue: CursorSubagentState.unknown) required this.state,  String? $type}): $type = $type ?? 'subagent_state_update';
  factory CursorSubagentStateUpdateDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentStateUpdateDtoFromJson(json);

 final  String subagentSessionId;
@JsonKey(unknownEnumValue: CursorSubagentState.unknown) final  CursorSubagentState state;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of CursorSubagentUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorSubagentStateUpdateDtoCopyWith<CursorSubagentStateUpdateDto> get copyWith => _$CursorSubagentStateUpdateDtoCopyWithImpl<CursorSubagentStateUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentStateUpdateDto&&(identical(other.subagentSessionId, subagentSessionId) || other.subagentSessionId == subagentSessionId)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,subagentSessionId,state);
}

@override
String toString() {
    return 'CursorSubagentUpdateDto.subagentStateUpdate(subagentSessionId: $subagentSessionId, state: $state)';
}


}

/// @nodoc
abstract mixin class $CursorSubagentStateUpdateDtoCopyWith<$Res> implements $CursorSubagentUpdateDtoCopyWith<$Res> {
  factory $CursorSubagentStateUpdateDtoCopyWith(CursorSubagentStateUpdateDto value, $Res Function(CursorSubagentStateUpdateDto) _then) = _$CursorSubagentStateUpdateDtoCopyWithImpl;
@useResult
$Res call({
 String subagentSessionId,@JsonKey(unknownEnumValue: CursorSubagentState.unknown) CursorSubagentState state
});




}
/// @nodoc
class _$CursorSubagentStateUpdateDtoCopyWithImpl<$Res>
    implements $CursorSubagentStateUpdateDtoCopyWith<$Res> {
  _$CursorSubagentStateUpdateDtoCopyWithImpl(this._self, this._then);

  final CursorSubagentStateUpdateDto _self;
  final $Res Function(CursorSubagentStateUpdateDto) _then;

/// Create a copy of CursorSubagentUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? subagentSessionId = null,Object? state = null,}) {
  return _then(CursorSubagentStateUpdateDto(
subagentSessionId: null == subagentSessionId ? _self.subagentSessionId : subagentSessionId // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CursorSubagentState,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CursorSubagentUpdateUnknownDto implements CursorSubagentUpdateDto {
  const CursorSubagentUpdateUnknownDto({ String? $type}): $type = $type ?? 'unknown';
  factory CursorSubagentUpdateUnknownDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentUpdateUnknownDtoFromJson(json);



@JsonKey(name: 'sessionUpdate')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentUpdateUnknownDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CursorSubagentUpdateDto.unknown()';
}


}





/// @nodoc
mixin _$CursorSubagentMetaDto {

 CursorSubagentCursorMetaDto? get cursor;
/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorSubagentMetaDtoCopyWith<CursorSubagentMetaDto> get copyWith => _$CursorSubagentMetaDtoCopyWithImpl<CursorSubagentMetaDto>(this as CursorSubagentMetaDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorSubagentMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentMetaDto&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorSubagentMetaDto;
  return Object.hash(runtimeType,_this.cursor);
}

@override
String toString() {
  final _this = this as CursorSubagentMetaDto;
  return 'CursorSubagentMetaDto(cursor: ${_this.cursor})';
}


}

/// @nodoc
abstract mixin class $CursorSubagentMetaDtoCopyWith<$Res>  {
  factory $CursorSubagentMetaDtoCopyWith(CursorSubagentMetaDto value, $Res Function(CursorSubagentMetaDto) _then) = _$CursorSubagentMetaDtoCopyWithImpl;
@useResult
$Res call({
 CursorSubagentCursorMetaDto? cursor
});


$CursorSubagentCursorMetaDtoCopyWith<$Res>? get cursor;

}
/// @nodoc
class _$CursorSubagentMetaDtoCopyWithImpl<$Res>
    implements $CursorSubagentMetaDtoCopyWith<$Res> {
  _$CursorSubagentMetaDtoCopyWithImpl(this._self, this._then);

  final CursorSubagentMetaDto _self;
  final $Res Function(CursorSubagentMetaDto) _then;

/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cursor = freezed,}) {
  return _then(CursorSubagentMetaDto(
cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as CursorSubagentCursorMetaDto?,
  ));
}
/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentCursorMetaDtoCopyWith<$Res>? get cursor {
    if (_self.cursor == null) {
    return null;
  }

  return $CursorSubagentCursorMetaDtoCopyWith<$Res>(_self.cursor!, (value) {
    return _then(_self.copyWith(cursor: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorSubagentMetaDto implements CursorSubagentMetaDto {
  const _CursorSubagentMetaDto({required this.cursor});
  factory _CursorSubagentMetaDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentMetaDtoFromJson(json);

@override final  CursorSubagentCursorMetaDto? cursor;

/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorSubagentMetaDtoCopyWith<_CursorSubagentMetaDto> get copyWith => __$CursorSubagentMetaDtoCopyWithImpl<_CursorSubagentMetaDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorSubagentMetaDto&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,cursor);
}

@override
String toString() {
    return 'CursorSubagentMetaDto(cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$CursorSubagentMetaDtoCopyWith<$Res> implements $CursorSubagentMetaDtoCopyWith<$Res> {
  factory _$CursorSubagentMetaDtoCopyWith(_CursorSubagentMetaDto value, $Res Function(_CursorSubagentMetaDto) _then) = __$CursorSubagentMetaDtoCopyWithImpl;
@override @useResult
$Res call({
 CursorSubagentCursorMetaDto? cursor
});


@override $CursorSubagentCursorMetaDtoCopyWith<$Res>? get cursor;

}
/// @nodoc
class __$CursorSubagentMetaDtoCopyWithImpl<$Res>
    implements _$CursorSubagentMetaDtoCopyWith<$Res> {
  __$CursorSubagentMetaDtoCopyWithImpl(this._self, this._then);

  final _CursorSubagentMetaDto _self;
  final $Res Function(_CursorSubagentMetaDto) _then;

/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cursor = freezed,}) {
  return _then(_CursorSubagentMetaDto(
cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as CursorSubagentCursorMetaDto?,
  ));
}

/// Create a copy of CursorSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentCursorMetaDtoCopyWith<$Res>? get cursor {
    if (_self.cursor == null) {
    return null;
  }

  return $CursorSubagentCursorMetaDtoCopyWith<$Res>(_self.cursor!, (value) {
    return _then(_self.copyWith(cursor: value));
  });
}
}


/// @nodoc
mixin _$CursorSubagentCursorMetaDto {

 String? get toolCallId; String? get model;
/// Create a copy of CursorSubagentCursorMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorSubagentCursorMetaDtoCopyWith<CursorSubagentCursorMetaDto> get copyWith => _$CursorSubagentCursorMetaDtoCopyWithImpl<CursorSubagentCursorMetaDto>(this as CursorSubagentCursorMetaDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorSubagentCursorMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentCursorMetaDto&&(identical(other.toolCallId, _this.toolCallId) || other.toolCallId == _this.toolCallId)&&(identical(other.model, _this.model) || other.model == _this.model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorSubagentCursorMetaDto;
  return Object.hash(runtimeType,_this.toolCallId,_this.model);
}

@override
String toString() {
  final _this = this as CursorSubagentCursorMetaDto;
  return 'CursorSubagentCursorMetaDto(toolCallId: ${_this.toolCallId}, model: ${_this.model})';
}


}

/// @nodoc
abstract mixin class $CursorSubagentCursorMetaDtoCopyWith<$Res>  {
  factory $CursorSubagentCursorMetaDtoCopyWith(CursorSubagentCursorMetaDto value, $Res Function(CursorSubagentCursorMetaDto) _then) = _$CursorSubagentCursorMetaDtoCopyWithImpl;
@useResult
$Res call({
 String? toolCallId, String? model
});




}
/// @nodoc
class _$CursorSubagentCursorMetaDtoCopyWithImpl<$Res>
    implements $CursorSubagentCursorMetaDtoCopyWith<$Res> {
  _$CursorSubagentCursorMetaDtoCopyWithImpl(this._self, this._then);

  final CursorSubagentCursorMetaDto _self;
  final $Res Function(CursorSubagentCursorMetaDto) _then;

/// Create a copy of CursorSubagentCursorMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = freezed,Object? model = freezed,}) {
  return _then(CursorSubagentCursorMetaDto(
toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorSubagentCursorMetaDto implements CursorSubagentCursorMetaDto {
  const _CursorSubagentCursorMetaDto({required this.toolCallId, required this.model});
  factory _CursorSubagentCursorMetaDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentCursorMetaDtoFromJson(json);

@override final  String? toolCallId;
@override final  String? model;

/// Create a copy of CursorSubagentCursorMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorSubagentCursorMetaDtoCopyWith<_CursorSubagentCursorMetaDto> get copyWith => __$CursorSubagentCursorMetaDtoCopyWithImpl<_CursorSubagentCursorMetaDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorSubagentCursorMetaDto&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolCallId,model);
}

@override
String toString() {
    return 'CursorSubagentCursorMetaDto(toolCallId: $toolCallId, model: $model)';
}


}

/// @nodoc
abstract mixin class _$CursorSubagentCursorMetaDtoCopyWith<$Res> implements $CursorSubagentCursorMetaDtoCopyWith<$Res> {
  factory _$CursorSubagentCursorMetaDtoCopyWith(_CursorSubagentCursorMetaDto value, $Res Function(_CursorSubagentCursorMetaDto) _then) = __$CursorSubagentCursorMetaDtoCopyWithImpl;
@override @useResult
$Res call({
 String? toolCallId, String? model
});




}
/// @nodoc
class __$CursorSubagentCursorMetaDtoCopyWithImpl<$Res>
    implements _$CursorSubagentCursorMetaDtoCopyWith<$Res> {
  __$CursorSubagentCursorMetaDtoCopyWithImpl(this._self, this._then);

  final _CursorSubagentCursorMetaDto _self;
  final $Res Function(_CursorSubagentCursorMetaDto) _then;

/// Create a copy of CursorSubagentCursorMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = freezed,Object? model = freezed,}) {
  return _then(_CursorSubagentCursorMetaDto(
toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
