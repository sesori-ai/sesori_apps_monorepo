// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cursor_task_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CursorTaskInputDto {

@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool get toolName;
/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskInputDtoCopyWith<CursorTaskInputDto> get copyWith => _$CursorTaskInputDtoCopyWithImpl<CursorTaskInputDto>(this as CursorTaskInputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskInputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskInputDto&&(identical(other.toolName, _this.toolName) || other.toolName == _this.toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskInputDto;
  return Object.hash(runtimeType,_this.toolName);
}

@override
String toString() {
  final _this = this as CursorTaskInputDto;
  return 'CursorTaskInputDto(toolName: ${_this.toolName})';
}


}

/// @nodoc
abstract mixin class $CursorTaskInputDtoCopyWith<$Res>  {
  factory $CursorTaskInputDtoCopyWith(CursorTaskInputDto value, $Res Function(CursorTaskInputDto) _then) = _$CursorTaskInputDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName
});




}
/// @nodoc
class _$CursorTaskInputDtoCopyWithImpl<$Res>
    implements $CursorTaskInputDtoCopyWith<$Res> {
  _$CursorTaskInputDtoCopyWithImpl(this._self, this._then);

  final CursorTaskInputDto _self;
  final $Res Function(CursorTaskInputDto) _then;

/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolName = null,}) {
  return _then(CursorTaskInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskInputDto implements CursorTaskInputDto {
  const _CursorTaskInputDto({@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) required this.toolName});
  factory _CursorTaskInputDto.fromJson(Map<String, dynamic> json) => _$CursorTaskInputDtoFromJson(json);

@override@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) final  CursorTaskTool toolName;

/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskInputDtoCopyWith<_CursorTaskInputDto> get copyWith => __$CursorTaskInputDtoCopyWithImpl<_CursorTaskInputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskInputDto&&(identical(other.toolName, toolName) || other.toolName == toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolName);
}

@override
String toString() {
    return 'CursorTaskInputDto(toolName: $toolName)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskInputDtoCopyWith<$Res> implements $CursorTaskInputDtoCopyWith<$Res> {
  factory _$CursorTaskInputDtoCopyWith(_CursorTaskInputDto value, $Res Function(_CursorTaskInputDto) _then) = __$CursorTaskInputDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName
});




}
/// @nodoc
class __$CursorTaskInputDtoCopyWithImpl<$Res>
    implements _$CursorTaskInputDtoCopyWith<$Res> {
  __$CursorTaskInputDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskInputDto _self;
  final $Res Function(_CursorTaskInputDto) _then;

/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolName = null,}) {
  return _then(_CursorTaskInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,
  ));
}


}


/// @nodoc
mixin _$CursorTaskOutputDto {

 bool get isBackground;
/// Create a copy of CursorTaskOutputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskOutputDtoCopyWith<CursorTaskOutputDto> get copyWith => _$CursorTaskOutputDtoCopyWithImpl<CursorTaskOutputDto>(this as CursorTaskOutputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskOutputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskOutputDto&&(identical(other.isBackground, _this.isBackground) || other.isBackground == _this.isBackground));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskOutputDto;
  return Object.hash(runtimeType,_this.isBackground);
}

@override
String toString() {
  final _this = this as CursorTaskOutputDto;
  return 'CursorTaskOutputDto(isBackground: ${_this.isBackground})';
}


}

/// @nodoc
abstract mixin class $CursorTaskOutputDtoCopyWith<$Res>  {
  factory $CursorTaskOutputDtoCopyWith(CursorTaskOutputDto value, $Res Function(CursorTaskOutputDto) _then) = _$CursorTaskOutputDtoCopyWithImpl;
@useResult
$Res call({
 bool isBackground
});




}
/// @nodoc
class _$CursorTaskOutputDtoCopyWithImpl<$Res>
    implements $CursorTaskOutputDtoCopyWith<$Res> {
  _$CursorTaskOutputDtoCopyWithImpl(this._self, this._then);

  final CursorTaskOutputDto _self;
  final $Res Function(CursorTaskOutputDto) _then;

/// Create a copy of CursorTaskOutputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isBackground = null,}) {
  return _then(CursorTaskOutputDto(
isBackground: null == isBackground ? _self.isBackground : isBackground // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskOutputDto implements CursorTaskOutputDto {
  const _CursorTaskOutputDto({required this.isBackground});
  factory _CursorTaskOutputDto.fromJson(Map<String, dynamic> json) => _$CursorTaskOutputDtoFromJson(json);

@override final  bool isBackground;

/// Create a copy of CursorTaskOutputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskOutputDtoCopyWith<_CursorTaskOutputDto> get copyWith => __$CursorTaskOutputDtoCopyWithImpl<_CursorTaskOutputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskOutputDto&&(identical(other.isBackground, isBackground) || other.isBackground == isBackground));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isBackground);
}

@override
String toString() {
    return 'CursorTaskOutputDto(isBackground: $isBackground)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskOutputDtoCopyWith<$Res> implements $CursorTaskOutputDtoCopyWith<$Res> {
  factory _$CursorTaskOutputDtoCopyWith(_CursorTaskOutputDto value, $Res Function(_CursorTaskOutputDto) _then) = __$CursorTaskOutputDtoCopyWithImpl;
@override @useResult
$Res call({
 bool isBackground
});




}
/// @nodoc
class __$CursorTaskOutputDtoCopyWithImpl<$Res>
    implements _$CursorTaskOutputDtoCopyWith<$Res> {
  __$CursorTaskOutputDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskOutputDto _self;
  final $Res Function(_CursorTaskOutputDto) _then;

/// Create a copy of CursorTaskOutputDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isBackground = null,}) {
  return _then(_CursorTaskOutputDto(
isBackground: null == isBackground ? _self.isBackground : isBackground // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CursorSubagentTypeDto {

@JsonKey(unknownEnumValue: CursorSubagentType.unknown) CursorSubagentType? get custom;
/// Create a copy of CursorSubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorSubagentTypeDtoCopyWith<CursorSubagentTypeDto> get copyWith => _$CursorSubagentTypeDtoCopyWithImpl<CursorSubagentTypeDto>(this as CursorSubagentTypeDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorSubagentTypeDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentTypeDto&&(identical(other.custom, _this.custom) || other.custom == _this.custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorSubagentTypeDto;
  return Object.hash(runtimeType,_this.custom);
}

@override
String toString() {
  final _this = this as CursorSubagentTypeDto;
  return 'CursorSubagentTypeDto(custom: ${_this.custom})';
}


}

/// @nodoc
abstract mixin class $CursorSubagentTypeDtoCopyWith<$Res>  {
  factory $CursorSubagentTypeDtoCopyWith(CursorSubagentTypeDto value, $Res Function(CursorSubagentTypeDto) _then) = _$CursorSubagentTypeDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CursorSubagentType.unknown) CursorSubagentType? custom
});




}
/// @nodoc
class _$CursorSubagentTypeDtoCopyWithImpl<$Res>
    implements $CursorSubagentTypeDtoCopyWith<$Res> {
  _$CursorSubagentTypeDtoCopyWithImpl(this._self, this._then);

  final CursorSubagentTypeDto _self;
  final $Res Function(CursorSubagentTypeDto) _then;

/// Create a copy of CursorSubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? custom = freezed,}) {
  return _then(CursorSubagentTypeDto(
custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as CursorSubagentType?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorSubagentTypeDto implements CursorSubagentTypeDto {
  const _CursorSubagentTypeDto({@JsonKey(unknownEnumValue: CursorSubagentType.unknown) required this.custom});
  factory _CursorSubagentTypeDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentTypeDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CursorSubagentType.unknown) final  CursorSubagentType? custom;

/// Create a copy of CursorSubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorSubagentTypeDtoCopyWith<_CursorSubagentTypeDto> get copyWith => __$CursorSubagentTypeDtoCopyWithImpl<_CursorSubagentTypeDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorSubagentTypeDto&&(identical(other.custom, custom) || other.custom == custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,custom);
}

@override
String toString() {
    return 'CursorSubagentTypeDto(custom: $custom)';
}


}

/// @nodoc
abstract mixin class _$CursorSubagentTypeDtoCopyWith<$Res> implements $CursorSubagentTypeDtoCopyWith<$Res> {
  factory _$CursorSubagentTypeDtoCopyWith(_CursorSubagentTypeDto value, $Res Function(_CursorSubagentTypeDto) _then) = __$CursorSubagentTypeDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CursorSubagentType.unknown) CursorSubagentType? custom
});




}
/// @nodoc
class __$CursorSubagentTypeDtoCopyWithImpl<$Res>
    implements _$CursorSubagentTypeDtoCopyWith<$Res> {
  __$CursorSubagentTypeDtoCopyWithImpl(this._self, this._then);

  final _CursorSubagentTypeDto _self;
  final $Res Function(_CursorSubagentTypeDto) _then;

/// Create a copy of CursorSubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? custom = freezed,}) {
  return _then(_CursorSubagentTypeDto(
custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as CursorSubagentType?,
  ));
}


}


/// @nodoc
mixin _$CursorTaskRequestDto {

 String get toolCallId; String get description; String get prompt; CursorSubagentTypeDto get subagentType;
/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskRequestDtoCopyWith<CursorTaskRequestDto> get copyWith => _$CursorTaskRequestDtoCopyWithImpl<CursorTaskRequestDto>(this as CursorTaskRequestDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskRequestDto&&(identical(other.toolCallId, _this.toolCallId) || other.toolCallId == _this.toolCallId)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.subagentType, _this.subagentType) || other.subagentType == _this.subagentType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskRequestDto;
  return Object.hash(runtimeType,_this.toolCallId,_this.description,_this.prompt,_this.subagentType);
}

@override
String toString() {
  final _this = this as CursorTaskRequestDto;
  return 'CursorTaskRequestDto(toolCallId: ${_this.toolCallId}, description: ${_this.description}, prompt: ${_this.prompt}, subagentType: ${_this.subagentType})';
}


}

/// @nodoc
abstract mixin class $CursorTaskRequestDtoCopyWith<$Res>  {
  factory $CursorTaskRequestDtoCopyWith(CursorTaskRequestDto value, $Res Function(CursorTaskRequestDto) _then) = _$CursorTaskRequestDtoCopyWithImpl;
@useResult
$Res call({
 String toolCallId, String description, String prompt, CursorSubagentTypeDto subagentType
});


$CursorSubagentTypeDtoCopyWith<$Res> get subagentType;

}
/// @nodoc
class _$CursorTaskRequestDtoCopyWithImpl<$Res>
    implements $CursorTaskRequestDtoCopyWith<$Res> {
  _$CursorTaskRequestDtoCopyWithImpl(this._self, this._then);

  final CursorTaskRequestDto _self;
  final $Res Function(CursorTaskRequestDto) _then;

/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,Object? description = null,Object? prompt = null,Object? subagentType = null,}) {
  return _then(CursorTaskRequestDto(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,subagentType: null == subagentType ? _self.subagentType : subagentType // ignore: cast_nullable_to_non_nullable
as CursorSubagentTypeDto,
  ));
}
/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentTypeDtoCopyWith<$Res> get subagentType {
  
  return $CursorSubagentTypeDtoCopyWith<$Res>(_self.subagentType, (value) {
    return _then(_self.copyWith(subagentType: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskRequestDto implements CursorTaskRequestDto {
  const _CursorTaskRequestDto({required this.toolCallId, required this.description, required this.prompt, required this.subagentType});
  factory _CursorTaskRequestDto.fromJson(Map<String, dynamic> json) => _$CursorTaskRequestDtoFromJson(json);

@override final  String toolCallId;
@override final  String description;
@override final  String prompt;
@override final  CursorSubagentTypeDto subagentType;

/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskRequestDtoCopyWith<_CursorTaskRequestDto> get copyWith => __$CursorTaskRequestDtoCopyWithImpl<_CursorTaskRequestDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskRequestDto&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.description, description) || other.description == description)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.subagentType, subagentType) || other.subagentType == subagentType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolCallId,description,prompt,subagentType);
}

@override
String toString() {
    return 'CursorTaskRequestDto(toolCallId: $toolCallId, description: $description, prompt: $prompt, subagentType: $subagentType)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskRequestDtoCopyWith<$Res> implements $CursorTaskRequestDtoCopyWith<$Res> {
  factory _$CursorTaskRequestDtoCopyWith(_CursorTaskRequestDto value, $Res Function(_CursorTaskRequestDto) _then) = __$CursorTaskRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String description, String prompt, CursorSubagentTypeDto subagentType
});


@override $CursorSubagentTypeDtoCopyWith<$Res> get subagentType;

}
/// @nodoc
class __$CursorTaskRequestDtoCopyWithImpl<$Res>
    implements _$CursorTaskRequestDtoCopyWith<$Res> {
  __$CursorTaskRequestDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskRequestDto _self;
  final $Res Function(_CursorTaskRequestDto) _then;

/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? description = null,Object? prompt = null,Object? subagentType = null,}) {
  return _then(_CursorTaskRequestDto(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,subagentType: null == subagentType ? _self.subagentType : subagentType // ignore: cast_nullable_to_non_nullable
as CursorSubagentTypeDto,
  ));
}

/// Create a copy of CursorTaskRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentTypeDtoCopyWith<$Res> get subagentType {
  
  return $CursorSubagentTypeDtoCopyWith<$Res>(_self.subagentType, (value) {
    return _then(_self.copyWith(subagentType: value));
  });
}
}

// dart format on
