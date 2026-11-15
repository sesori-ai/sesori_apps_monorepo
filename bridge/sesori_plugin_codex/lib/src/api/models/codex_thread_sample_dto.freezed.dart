// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_thread_sample_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexThreadSampleDto {

/// The reply text; null when the model tried a tool call or gave no text.
 String? get text;
/// Create a copy of CodexThreadSampleDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadSampleDtoCopyWith<CodexThreadSampleDto> get copyWith => _$CodexThreadSampleDtoCopyWithImpl<CodexThreadSampleDto>(this as CodexThreadSampleDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexThreadSampleDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadSampleDto&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexThreadSampleDto;
  return Object.hash(runtimeType,_this.text);
}

@override
String toString() {
  final _this = this as CodexThreadSampleDto;
  return 'CodexThreadSampleDto(text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $CodexThreadSampleDtoCopyWith<$Res>  {
  factory $CodexThreadSampleDtoCopyWith(CodexThreadSampleDto value, $Res Function(CodexThreadSampleDto) _then) = _$CodexThreadSampleDtoCopyWithImpl;
@useResult
$Res call({
 String? text
});




}
/// @nodoc
class _$CodexThreadSampleDtoCopyWithImpl<$Res>
    implements $CodexThreadSampleDtoCopyWith<$Res> {
  _$CodexThreadSampleDtoCopyWithImpl(this._self, this._then);

  final CodexThreadSampleDto _self;
  final $Res Function(CodexThreadSampleDto) _then;

/// Create a copy of CodexThreadSampleDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = freezed,}) {
  return _then(CodexThreadSampleDto(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadSampleDto implements CodexThreadSampleDto {
  const _CodexThreadSampleDto({required this.text});
  factory _CodexThreadSampleDto.fromJson(Map<String, dynamic> json) => _$CodexThreadSampleDtoFromJson(json);

/// The reply text; null when the model tried a tool call or gave no text.
@override final  String? text;

/// Create a copy of CodexThreadSampleDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadSampleDtoCopyWith<_CodexThreadSampleDto> get copyWith => __$CodexThreadSampleDtoCopyWithImpl<_CodexThreadSampleDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadSampleDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'CodexThreadSampleDto(text: $text)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadSampleDtoCopyWith<$Res> implements $CodexThreadSampleDtoCopyWith<$Res> {
  factory _$CodexThreadSampleDtoCopyWith(_CodexThreadSampleDto value, $Res Function(_CodexThreadSampleDto) _then) = __$CodexThreadSampleDtoCopyWithImpl;
@override @useResult
$Res call({
 String? text
});




}
/// @nodoc
class __$CodexThreadSampleDtoCopyWithImpl<$Res>
    implements _$CodexThreadSampleDtoCopyWith<$Res> {
  __$CodexThreadSampleDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadSampleDto _self;
  final $Res Function(_CodexThreadSampleDto) _then;

/// Create a copy of CodexThreadSampleDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = freezed,}) {
  return _then(_CodexThreadSampleDto(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
