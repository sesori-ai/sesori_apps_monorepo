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

// dart format on
