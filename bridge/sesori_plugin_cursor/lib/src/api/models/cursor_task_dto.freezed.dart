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

@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool get toolName; String? get prompt; String? get description;
/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskInputDtoCopyWith<CursorTaskInputDto> get copyWith => _$CursorTaskInputDtoCopyWithImpl<CursorTaskInputDto>(this as CursorTaskInputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskInputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskInputDto&&(identical(other.toolName, _this.toolName) || other.toolName == _this.toolName)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskInputDto;
  return Object.hash(runtimeType,_this.toolName,_this.prompt,_this.description);
}

@override
String toString() {
  final _this = this as CursorTaskInputDto;
  return 'CursorTaskInputDto(toolName: ${_this.toolName}, prompt: ${_this.prompt}, description: ${_this.description})';
}


}

/// @nodoc
abstract mixin class $CursorTaskInputDtoCopyWith<$Res>  {
  factory $CursorTaskInputDtoCopyWith(CursorTaskInputDto value, $Res Function(CursorTaskInputDto) _then) = _$CursorTaskInputDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName, String? prompt, String? description
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
@pragma('vm:prefer-inline') @override $Res call({Object? toolName = null,Object? prompt = freezed,Object? description = freezed,}) {
  return _then(CursorTaskInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskInputDto implements CursorTaskInputDto {
  const _CursorTaskInputDto({@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) required this.toolName, required this.prompt, required this.description});
  factory _CursorTaskInputDto.fromJson(Map<String, dynamic> json) => _$CursorTaskInputDtoFromJson(json);

@override@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) final  CursorTaskTool toolName;
@override final  String? prompt;
@override final  String? description;

/// Create a copy of CursorTaskInputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskInputDtoCopyWith<_CursorTaskInputDto> get copyWith => __$CursorTaskInputDtoCopyWithImpl<_CursorTaskInputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskInputDto&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolName,prompt,description);
}

@override
String toString() {
    return 'CursorTaskInputDto(toolName: $toolName, prompt: $prompt, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskInputDtoCopyWith<$Res> implements $CursorTaskInputDtoCopyWith<$Res> {
  factory _$CursorTaskInputDtoCopyWith(_CursorTaskInputDto value, $Res Function(_CursorTaskInputDto) _then) = __$CursorTaskInputDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName, String? prompt, String? description
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
@override @pragma('vm:prefer-inline') $Res call({Object? toolName = null,Object? prompt = freezed,Object? description = freezed,}) {
  return _then(_CursorTaskInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
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
mixin _$CursorSubagentUnspecifiedDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorSubagentUnspecifiedDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CursorSubagentUnspecifiedDto()';
}


}

/// @nodoc
class $CursorSubagentUnspecifiedDtoCopyWith<$Res>  {
$CursorSubagentUnspecifiedDtoCopyWith(CursorSubagentUnspecifiedDto _, $Res Function(CursorSubagentUnspecifiedDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorSubagentUnspecifiedDto implements CursorSubagentUnspecifiedDto {
  const _CursorSubagentUnspecifiedDto();
  factory _CursorSubagentUnspecifiedDto.fromJson(Map<String, dynamic> json) => _$CursorSubagentUnspecifiedDtoFromJson(json);






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorSubagentUnspecifiedDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CursorSubagentUnspecifiedDto()';
}


}





/// @nodoc
mixin _$CursorTaskReplaySubagentTypeDto {

 CursorSubagentUnspecifiedDto? get unspecified;
/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskReplaySubagentTypeDtoCopyWith<CursorTaskReplaySubagentTypeDto> get copyWith => _$CursorTaskReplaySubagentTypeDtoCopyWithImpl<CursorTaskReplaySubagentTypeDto>(this as CursorTaskReplaySubagentTypeDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskReplaySubagentTypeDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskReplaySubagentTypeDto&&(identical(other.unspecified, _this.unspecified) || other.unspecified == _this.unspecified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskReplaySubagentTypeDto;
  return Object.hash(runtimeType,_this.unspecified);
}

@override
String toString() {
  final _this = this as CursorTaskReplaySubagentTypeDto;
  return 'CursorTaskReplaySubagentTypeDto(unspecified: ${_this.unspecified})';
}


}

/// @nodoc
abstract mixin class $CursorTaskReplaySubagentTypeDtoCopyWith<$Res>  {
  factory $CursorTaskReplaySubagentTypeDtoCopyWith(CursorTaskReplaySubagentTypeDto value, $Res Function(CursorTaskReplaySubagentTypeDto) _then) = _$CursorTaskReplaySubagentTypeDtoCopyWithImpl;
@useResult
$Res call({
 CursorSubagentUnspecifiedDto? unspecified
});


$CursorSubagentUnspecifiedDtoCopyWith<$Res>? get unspecified;

}
/// @nodoc
class _$CursorTaskReplaySubagentTypeDtoCopyWithImpl<$Res>
    implements $CursorTaskReplaySubagentTypeDtoCopyWith<$Res> {
  _$CursorTaskReplaySubagentTypeDtoCopyWithImpl(this._self, this._then);

  final CursorTaskReplaySubagentTypeDto _self;
  final $Res Function(CursorTaskReplaySubagentTypeDto) _then;

/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unspecified = freezed,}) {
  return _then(CursorTaskReplaySubagentTypeDto(
unspecified: freezed == unspecified ? _self.unspecified : unspecified // ignore: cast_nullable_to_non_nullable
as CursorSubagentUnspecifiedDto?,
  ));
}
/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentUnspecifiedDtoCopyWith<$Res>? get unspecified {
    if (_self.unspecified == null) {
    return null;
  }

  return $CursorSubagentUnspecifiedDtoCopyWith<$Res>(_self.unspecified!, (value) {
    return _then(_self.copyWith(unspecified: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskReplaySubagentTypeDto implements CursorTaskReplaySubagentTypeDto {
  const _CursorTaskReplaySubagentTypeDto({required this.unspecified});
  factory _CursorTaskReplaySubagentTypeDto.fromJson(Map<String, dynamic> json) => _$CursorTaskReplaySubagentTypeDtoFromJson(json);

@override final  CursorSubagentUnspecifiedDto? unspecified;

/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskReplaySubagentTypeDtoCopyWith<_CursorTaskReplaySubagentTypeDto> get copyWith => __$CursorTaskReplaySubagentTypeDtoCopyWithImpl<_CursorTaskReplaySubagentTypeDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskReplaySubagentTypeDto&&(identical(other.unspecified, unspecified) || other.unspecified == unspecified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,unspecified);
}

@override
String toString() {
    return 'CursorTaskReplaySubagentTypeDto(unspecified: $unspecified)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskReplaySubagentTypeDtoCopyWith<$Res> implements $CursorTaskReplaySubagentTypeDtoCopyWith<$Res> {
  factory _$CursorTaskReplaySubagentTypeDtoCopyWith(_CursorTaskReplaySubagentTypeDto value, $Res Function(_CursorTaskReplaySubagentTypeDto) _then) = __$CursorTaskReplaySubagentTypeDtoCopyWithImpl;
@override @useResult
$Res call({
 CursorSubagentUnspecifiedDto? unspecified
});


@override $CursorSubagentUnspecifiedDtoCopyWith<$Res>? get unspecified;

}
/// @nodoc
class __$CursorTaskReplaySubagentTypeDtoCopyWithImpl<$Res>
    implements _$CursorTaskReplaySubagentTypeDtoCopyWith<$Res> {
  __$CursorTaskReplaySubagentTypeDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskReplaySubagentTypeDto _self;
  final $Res Function(_CursorTaskReplaySubagentTypeDto) _then;

/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unspecified = freezed,}) {
  return _then(_CursorTaskReplaySubagentTypeDto(
unspecified: freezed == unspecified ? _self.unspecified : unspecified // ignore: cast_nullable_to_non_nullable
as CursorSubagentUnspecifiedDto?,
  ));
}

/// Create a copy of CursorTaskReplaySubagentTypeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorSubagentUnspecifiedDtoCopyWith<$Res>? get unspecified {
    if (_self.unspecified == null) {
    return null;
  }

  return $CursorSubagentUnspecifiedDtoCopyWith<$Res>(_self.unspecified!, (value) {
    return _then(_self.copyWith(unspecified: value));
  });
}
}


/// @nodoc
mixin _$CursorTaskReplayInputDto {

@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool get toolName; String? get prompt; String? get description; CursorTaskReplaySubagentTypeDto? get subagentType;
/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskReplayInputDtoCopyWith<CursorTaskReplayInputDto> get copyWith => _$CursorTaskReplayInputDtoCopyWithImpl<CursorTaskReplayInputDto>(this as CursorTaskReplayInputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskReplayInputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskReplayInputDto&&(identical(other.toolName, _this.toolName) || other.toolName == _this.toolName)&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.subagentType, _this.subagentType) || other.subagentType == _this.subagentType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskReplayInputDto;
  return Object.hash(runtimeType,_this.toolName,_this.prompt,_this.description,_this.subagentType);
}

@override
String toString() {
  final _this = this as CursorTaskReplayInputDto;
  return 'CursorTaskReplayInputDto(toolName: ${_this.toolName}, prompt: ${_this.prompt}, description: ${_this.description}, subagentType: ${_this.subagentType})';
}


}

/// @nodoc
abstract mixin class $CursorTaskReplayInputDtoCopyWith<$Res>  {
  factory $CursorTaskReplayInputDtoCopyWith(CursorTaskReplayInputDto value, $Res Function(CursorTaskReplayInputDto) _then) = _$CursorTaskReplayInputDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName, String? prompt, String? description, CursorTaskReplaySubagentTypeDto? subagentType
});


$CursorTaskReplaySubagentTypeDtoCopyWith<$Res>? get subagentType;

}
/// @nodoc
class _$CursorTaskReplayInputDtoCopyWithImpl<$Res>
    implements $CursorTaskReplayInputDtoCopyWith<$Res> {
  _$CursorTaskReplayInputDtoCopyWithImpl(this._self, this._then);

  final CursorTaskReplayInputDto _self;
  final $Res Function(CursorTaskReplayInputDto) _then;

/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolName = null,Object? prompt = freezed,Object? description = freezed,Object? subagentType = freezed,}) {
  return _then(CursorTaskReplayInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,subagentType: freezed == subagentType ? _self.subagentType : subagentType // ignore: cast_nullable_to_non_nullable
as CursorTaskReplaySubagentTypeDto?,
  ));
}
/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorTaskReplaySubagentTypeDtoCopyWith<$Res>? get subagentType {
    if (_self.subagentType == null) {
    return null;
  }

  return $CursorTaskReplaySubagentTypeDtoCopyWith<$Res>(_self.subagentType!, (value) {
    return _then(_self.copyWith(subagentType: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskReplayInputDto implements CursorTaskReplayInputDto {
  const _CursorTaskReplayInputDto({@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) required this.toolName, required this.prompt, required this.description, required this.subagentType});
  factory _CursorTaskReplayInputDto.fromJson(Map<String, dynamic> json) => _$CursorTaskReplayInputDtoFromJson(json);

@override@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) final  CursorTaskTool toolName;
@override final  String? prompt;
@override final  String? description;
@override final  CursorTaskReplaySubagentTypeDto? subagentType;

/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskReplayInputDtoCopyWith<_CursorTaskReplayInputDto> get copyWith => __$CursorTaskReplayInputDtoCopyWithImpl<_CursorTaskReplayInputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskReplayInputDto&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.subagentType, subagentType) || other.subagentType == subagentType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolName,prompt,description,subagentType);
}

@override
String toString() {
    return 'CursorTaskReplayInputDto(toolName: $toolName, prompt: $prompt, description: $description, subagentType: $subagentType)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskReplayInputDtoCopyWith<$Res> implements $CursorTaskReplayInputDtoCopyWith<$Res> {
  factory _$CursorTaskReplayInputDtoCopyWith(_CursorTaskReplayInputDto value, $Res Function(_CursorTaskReplayInputDto) _then) = __$CursorTaskReplayInputDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "_toolName", unknownEnumValue: CursorTaskTool.unknown) CursorTaskTool toolName, String? prompt, String? description, CursorTaskReplaySubagentTypeDto? subagentType
});


@override $CursorTaskReplaySubagentTypeDtoCopyWith<$Res>? get subagentType;

}
/// @nodoc
class __$CursorTaskReplayInputDtoCopyWithImpl<$Res>
    implements _$CursorTaskReplayInputDtoCopyWith<$Res> {
  __$CursorTaskReplayInputDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskReplayInputDto _self;
  final $Res Function(_CursorTaskReplayInputDto) _then;

/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolName = null,Object? prompt = freezed,Object? description = freezed,Object? subagentType = freezed,}) {
  return _then(_CursorTaskReplayInputDto(
toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as CursorTaskTool,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,subagentType: freezed == subagentType ? _self.subagentType : subagentType // ignore: cast_nullable_to_non_nullable
as CursorTaskReplaySubagentTypeDto?,
  ));
}

/// Create a copy of CursorTaskReplayInputDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CursorTaskReplaySubagentTypeDtoCopyWith<$Res>? get subagentType {
    if (_self.subagentType == null) {
    return null;
  }

  return $CursorTaskReplaySubagentTypeDtoCopyWith<$Res>(_self.subagentType!, (value) {
    return _then(_self.copyWith(subagentType: value));
  });
}
}


/// @nodoc
mixin _$CursorTaskReplayUpdateDto {

@JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) CursorTaskReplayUpdateKind get sessionUpdate; String? get toolCallId;@JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) CursorTaskReplayStatus? get status;
/// Create a copy of CursorTaskReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorTaskReplayUpdateDtoCopyWith<CursorTaskReplayUpdateDto> get copyWith => _$CursorTaskReplayUpdateDtoCopyWithImpl<CursorTaskReplayUpdateDto>(this as CursorTaskReplayUpdateDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CursorTaskReplayUpdateDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorTaskReplayUpdateDto&&(identical(other.sessionUpdate, _this.sessionUpdate) || other.sessionUpdate == _this.sessionUpdate)&&(identical(other.toolCallId, _this.toolCallId) || other.toolCallId == _this.toolCallId)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CursorTaskReplayUpdateDto;
  return Object.hash(runtimeType,_this.sessionUpdate,_this.toolCallId,_this.status);
}

@override
String toString() {
  final _this = this as CursorTaskReplayUpdateDto;
  return 'CursorTaskReplayUpdateDto(sessionUpdate: ${_this.sessionUpdate}, toolCallId: ${_this.toolCallId}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $CursorTaskReplayUpdateDtoCopyWith<$Res>  {
  factory $CursorTaskReplayUpdateDtoCopyWith(CursorTaskReplayUpdateDto value, $Res Function(CursorTaskReplayUpdateDto) _then) = _$CursorTaskReplayUpdateDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) CursorTaskReplayUpdateKind sessionUpdate, String? toolCallId,@JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) CursorTaskReplayStatus? status
});




}
/// @nodoc
class _$CursorTaskReplayUpdateDtoCopyWithImpl<$Res>
    implements $CursorTaskReplayUpdateDtoCopyWith<$Res> {
  _$CursorTaskReplayUpdateDtoCopyWithImpl(this._self, this._then);

  final CursorTaskReplayUpdateDto _self;
  final $Res Function(CursorTaskReplayUpdateDto) _then;

/// Create a copy of CursorTaskReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionUpdate = null,Object? toolCallId = freezed,Object? status = freezed,}) {
  return _then(CursorTaskReplayUpdateDto(
sessionUpdate: null == sessionUpdate ? _self.sessionUpdate : sessionUpdate // ignore: cast_nullable_to_non_nullable
as CursorTaskReplayUpdateKind,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CursorTaskReplayStatus?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorTaskReplayUpdateDto implements CursorTaskReplayUpdateDto {
  const _CursorTaskReplayUpdateDto({@JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) required this.sessionUpdate, required this.toolCallId, @JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) required this.status});
  factory _CursorTaskReplayUpdateDto.fromJson(Map<String, dynamic> json) => _$CursorTaskReplayUpdateDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) final  CursorTaskReplayUpdateKind sessionUpdate;
@override final  String? toolCallId;
@override@JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) final  CursorTaskReplayStatus? status;

/// Create a copy of CursorTaskReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorTaskReplayUpdateDtoCopyWith<_CursorTaskReplayUpdateDto> get copyWith => __$CursorTaskReplayUpdateDtoCopyWithImpl<_CursorTaskReplayUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorTaskReplayUpdateDto&&(identical(other.sessionUpdate, sessionUpdate) || other.sessionUpdate == sessionUpdate)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionUpdate,toolCallId,status);
}

@override
String toString() {
    return 'CursorTaskReplayUpdateDto(sessionUpdate: $sessionUpdate, toolCallId: $toolCallId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CursorTaskReplayUpdateDtoCopyWith<$Res> implements $CursorTaskReplayUpdateDtoCopyWith<$Res> {
  factory _$CursorTaskReplayUpdateDtoCopyWith(_CursorTaskReplayUpdateDto value, $Res Function(_CursorTaskReplayUpdateDto) _then) = __$CursorTaskReplayUpdateDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) CursorTaskReplayUpdateKind sessionUpdate, String? toolCallId,@JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) CursorTaskReplayStatus? status
});




}
/// @nodoc
class __$CursorTaskReplayUpdateDtoCopyWithImpl<$Res>
    implements _$CursorTaskReplayUpdateDtoCopyWith<$Res> {
  __$CursorTaskReplayUpdateDtoCopyWithImpl(this._self, this._then);

  final _CursorTaskReplayUpdateDto _self;
  final $Res Function(_CursorTaskReplayUpdateDto) _then;

/// Create a copy of CursorTaskReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionUpdate = null,Object? toolCallId = freezed,Object? status = freezed,}) {
  return _then(_CursorTaskReplayUpdateDto(
sessionUpdate: null == sessionUpdate ? _self.sessionUpdate : sessionUpdate // ignore: cast_nullable_to_non_nullable
as CursorTaskReplayUpdateKind,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CursorTaskReplayStatus?,
  ));
}


}

// dart format on
