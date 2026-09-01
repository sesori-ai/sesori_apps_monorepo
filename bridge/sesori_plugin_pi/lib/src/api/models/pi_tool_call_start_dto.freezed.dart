// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_tool_call_start_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PiToolCallStartDto {

@JsonKey(fromJson: intOrNull) int? get contentIndex;@JsonKey(fromJson: stringOrNull) String? get id;@JsonKey(fromJson: stringOrNull) String? get toolName;
/// Create a copy of PiToolCallStartDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiToolCallStartDtoCopyWith<PiToolCallStartDto> get copyWith => _$PiToolCallStartDtoCopyWithImpl<PiToolCallStartDto>(this as PiToolCallStartDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiToolCallStartDto&&(identical(other.contentIndex, contentIndex) || other.contentIndex == contentIndex)&&(identical(other.id, id) || other.id == id)&&(identical(other.toolName, toolName) || other.toolName == toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,contentIndex,id,toolName);



}

/// @nodoc
abstract mixin class $PiToolCallStartDtoCopyWith<$Res>  {
  factory $PiToolCallStartDtoCopyWith(PiToolCallStartDto value, $Res Function(PiToolCallStartDto) _then) = _$PiToolCallStartDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: intOrNull) int? contentIndex,@JsonKey(fromJson: stringOrNull) String? id,@JsonKey(fromJson: stringOrNull) String? toolName
});




}
/// @nodoc
class _$PiToolCallStartDtoCopyWithImpl<$Res>
    implements $PiToolCallStartDtoCopyWith<$Res> {
  _$PiToolCallStartDtoCopyWithImpl(this._self, this._then);

  final PiToolCallStartDto _self;
  final $Res Function(PiToolCallStartDto) _then;

/// Create a copy of PiToolCallStartDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? contentIndex = freezed,Object? id = freezed,Object? toolName = freezed,}) {
  return _then(PiToolCallStartDto(
contentIndex: freezed == contentIndex ? _self.contentIndex : contentIndex // ignore: cast_nullable_to_non_nullable
as int?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiToolCallStartDto implements PiToolCallStartDto {
  const _PiToolCallStartDto({@JsonKey(fromJson: intOrNull) required this.contentIndex, @JsonKey(fromJson: stringOrNull) required this.id, @JsonKey(fromJson: stringOrNull) required this.toolName});
  factory _PiToolCallStartDto.fromJson(Map<String, dynamic> json) => _$PiToolCallStartDtoFromJson(json);

@override@JsonKey(fromJson: intOrNull) final  int? contentIndex;
@override@JsonKey(fromJson: stringOrNull) final  String? id;
@override@JsonKey(fromJson: stringOrNull) final  String? toolName;

/// Create a copy of PiToolCallStartDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiToolCallStartDtoCopyWith<_PiToolCallStartDto> get copyWith => __$PiToolCallStartDtoCopyWithImpl<_PiToolCallStartDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiToolCallStartDto&&(identical(other.contentIndex, contentIndex) || other.contentIndex == contentIndex)&&(identical(other.id, id) || other.id == id)&&(identical(other.toolName, toolName) || other.toolName == toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,contentIndex,id,toolName);



}

/// @nodoc
abstract mixin class _$PiToolCallStartDtoCopyWith<$Res> implements $PiToolCallStartDtoCopyWith<$Res> {
  factory _$PiToolCallStartDtoCopyWith(_PiToolCallStartDto value, $Res Function(_PiToolCallStartDto) _then) = __$PiToolCallStartDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: intOrNull) int? contentIndex,@JsonKey(fromJson: stringOrNull) String? id,@JsonKey(fromJson: stringOrNull) String? toolName
});




}
/// @nodoc
class __$PiToolCallStartDtoCopyWithImpl<$Res>
    implements _$PiToolCallStartDtoCopyWith<$Res> {
  __$PiToolCallStartDtoCopyWithImpl(this._self, this._then);

  final _PiToolCallStartDto _self;
  final $Res Function(_PiToolCallStartDto) _then;

/// Create a copy of PiToolCallStartDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? contentIndex = freezed,Object? id = freezed,Object? toolName = freezed,}) {
  return _then(_PiToolCallStartDto(
contentIndex: freezed == contentIndex ? _self.contentIndex : contentIndex // ignore: cast_nullable_to_non_nullable
as int?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
