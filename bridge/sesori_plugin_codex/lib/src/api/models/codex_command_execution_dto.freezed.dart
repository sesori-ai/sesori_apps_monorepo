// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_command_execution_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexCommandExecutionParamsDto {

 String? get threadId; String? get turnId; CodexCommandExecutionItemDto get item;
/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCommandExecutionParamsDtoCopyWith<CodexCommandExecutionParamsDto> get copyWith => _$CodexCommandExecutionParamsDtoCopyWithImpl<CodexCommandExecutionParamsDto>(this as CodexCommandExecutionParamsDto, _$identity);

  /// Serializes this CodexCommandExecutionParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCommandExecutionParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexCommandExecutionParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class $CodexCommandExecutionParamsDtoCopyWith<$Res>  {
  factory $CodexCommandExecutionParamsDtoCopyWith(CodexCommandExecutionParamsDto value, $Res Function(CodexCommandExecutionParamsDto) _then) = _$CodexCommandExecutionParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? threadId, String? turnId, CodexCommandExecutionItemDto item
});


$CodexCommandExecutionItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class _$CodexCommandExecutionParamsDtoCopyWithImpl<$Res>
    implements $CodexCommandExecutionParamsDtoCopyWith<$Res> {
  _$CodexCommandExecutionParamsDtoCopyWithImpl(this._self, this._then);

  final CodexCommandExecutionParamsDto _self;
  final $Res Function(CodexCommandExecutionParamsDto) _then;

/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(_self.copyWith(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionItemDto,
  ));
}
/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexCommandExecutionItemDtoCopyWith<$Res> get item {
  
  return $CodexCommandExecutionItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexCommandExecutionParamsDto implements CodexCommandExecutionParamsDto {
  const _CodexCommandExecutionParamsDto({required this.threadId, required this.turnId, required this.item});
  factory _CodexCommandExecutionParamsDto.fromJson(Map<String, dynamic> json) => _$CodexCommandExecutionParamsDtoFromJson(json);

@override final  String? threadId;
@override final  String? turnId;
@override final  CodexCommandExecutionItemDto item;

/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexCommandExecutionParamsDtoCopyWith<_CodexCommandExecutionParamsDto> get copyWith => __$CodexCommandExecutionParamsDtoCopyWithImpl<_CodexCommandExecutionParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexCommandExecutionParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexCommandExecutionParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexCommandExecutionParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class _$CodexCommandExecutionParamsDtoCopyWith<$Res> implements $CodexCommandExecutionParamsDtoCopyWith<$Res> {
  factory _$CodexCommandExecutionParamsDtoCopyWith(_CodexCommandExecutionParamsDto value, $Res Function(_CodexCommandExecutionParamsDto) _then) = __$CodexCommandExecutionParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? threadId, String? turnId, CodexCommandExecutionItemDto item
});


@override $CodexCommandExecutionItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class __$CodexCommandExecutionParamsDtoCopyWithImpl<$Res>
    implements _$CodexCommandExecutionParamsDtoCopyWith<$Res> {
  __$CodexCommandExecutionParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexCommandExecutionParamsDto _self;
  final $Res Function(_CodexCommandExecutionParamsDto) _then;

/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(_CodexCommandExecutionParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionItemDto,
  ));
}

/// Create a copy of CodexCommandExecutionParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexCommandExecutionItemDtoCopyWith<$Res> get item {
  
  return $CodexCommandExecutionItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$CodexCommandExecutionItemDto {

@JsonKey(unknownEnumValue: CodexCommandExecutionItemType.unknown, defaultValue: CodexCommandExecutionItemType.unknown) CodexCommandExecutionItemType get type; String? get id;@JsonKey(fromJson: _commandExecutionStatusFromJson) CodexCommandExecutionStatus get status;@JsonKey(fromJson: _commandExecutionExitCodeFromJson) int? get exitCode;
/// Create a copy of CodexCommandExecutionItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCommandExecutionItemDtoCopyWith<CodexCommandExecutionItemDto> get copyWith => _$CodexCommandExecutionItemDtoCopyWithImpl<CodexCommandExecutionItemDto>(this as CodexCommandExecutionItemDto, _$identity);

  /// Serializes this CodexCommandExecutionItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCommandExecutionItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,status,exitCode);

@override
String toString() {
  return 'CodexCommandExecutionItemDto(type: $type, id: $id, status: $status, exitCode: $exitCode)';
}


}

/// @nodoc
abstract mixin class $CodexCommandExecutionItemDtoCopyWith<$Res>  {
  factory $CodexCommandExecutionItemDtoCopyWith(CodexCommandExecutionItemDto value, $Res Function(CodexCommandExecutionItemDto) _then) = _$CodexCommandExecutionItemDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexCommandExecutionItemType.unknown, defaultValue: CodexCommandExecutionItemType.unknown) CodexCommandExecutionItemType type, String? id,@JsonKey(fromJson: _commandExecutionStatusFromJson) CodexCommandExecutionStatus status,@JsonKey(fromJson: _commandExecutionExitCodeFromJson) int? exitCode
});




}
/// @nodoc
class _$CodexCommandExecutionItemDtoCopyWithImpl<$Res>
    implements $CodexCommandExecutionItemDtoCopyWith<$Res> {
  _$CodexCommandExecutionItemDtoCopyWithImpl(this._self, this._then);

  final CodexCommandExecutionItemDto _self;
  final $Res Function(CodexCommandExecutionItemDto) _then;

/// Create a copy of CodexCommandExecutionItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = freezed,Object? status = null,Object? exitCode = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionStatus,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexCommandExecutionItemDto implements CodexCommandExecutionItemDto {
  const _CodexCommandExecutionItemDto({@JsonKey(unknownEnumValue: CodexCommandExecutionItemType.unknown, defaultValue: CodexCommandExecutionItemType.unknown) required this.type, required this.id, @JsonKey(fromJson: _commandExecutionStatusFromJson) required this.status, @JsonKey(fromJson: _commandExecutionExitCodeFromJson) required this.exitCode});
  factory _CodexCommandExecutionItemDto.fromJson(Map<String, dynamic> json) => _$CodexCommandExecutionItemDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexCommandExecutionItemType.unknown, defaultValue: CodexCommandExecutionItemType.unknown) final  CodexCommandExecutionItemType type;
@override final  String? id;
@override@JsonKey(fromJson: _commandExecutionStatusFromJson) final  CodexCommandExecutionStatus status;
@override@JsonKey(fromJson: _commandExecutionExitCodeFromJson) final  int? exitCode;

/// Create a copy of CodexCommandExecutionItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexCommandExecutionItemDtoCopyWith<_CodexCommandExecutionItemDto> get copyWith => __$CodexCommandExecutionItemDtoCopyWithImpl<_CodexCommandExecutionItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexCommandExecutionItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexCommandExecutionItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,status,exitCode);

@override
String toString() {
  return 'CodexCommandExecutionItemDto(type: $type, id: $id, status: $status, exitCode: $exitCode)';
}


}

/// @nodoc
abstract mixin class _$CodexCommandExecutionItemDtoCopyWith<$Res> implements $CodexCommandExecutionItemDtoCopyWith<$Res> {
  factory _$CodexCommandExecutionItemDtoCopyWith(_CodexCommandExecutionItemDto value, $Res Function(_CodexCommandExecutionItemDto) _then) = __$CodexCommandExecutionItemDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexCommandExecutionItemType.unknown, defaultValue: CodexCommandExecutionItemType.unknown) CodexCommandExecutionItemType type, String? id,@JsonKey(fromJson: _commandExecutionStatusFromJson) CodexCommandExecutionStatus status,@JsonKey(fromJson: _commandExecutionExitCodeFromJson) int? exitCode
});




}
/// @nodoc
class __$CodexCommandExecutionItemDtoCopyWithImpl<$Res>
    implements _$CodexCommandExecutionItemDtoCopyWith<$Res> {
  __$CodexCommandExecutionItemDtoCopyWithImpl(this._self, this._then);

  final _CodexCommandExecutionItemDto _self;
  final $Res Function(_CodexCommandExecutionItemDto) _then;

/// Create a copy of CodexCommandExecutionItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = freezed,Object? status = null,Object? exitCode = freezed,}) {
  return _then(_CodexCommandExecutionItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexCommandExecutionStatus,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
