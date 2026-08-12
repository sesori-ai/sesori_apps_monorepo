// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_auth_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeAuthStatusDto {

@JsonKey(fromJson: _boolOrNull) bool? get loggedIn;
/// Create a copy of ClaudeAuthStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeAuthStatusDtoCopyWith<ClaudeAuthStatusDto> get copyWith => _$ClaudeAuthStatusDtoCopyWithImpl<ClaudeAuthStatusDto>(this as ClaudeAuthStatusDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeAuthStatusDto&&(identical(other.loggedIn, loggedIn) || other.loggedIn == loggedIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loggedIn);



}

/// @nodoc
abstract mixin class $ClaudeAuthStatusDtoCopyWith<$Res>  {
  factory $ClaudeAuthStatusDtoCopyWith(ClaudeAuthStatusDto value, $Res Function(ClaudeAuthStatusDto) _then) = _$ClaudeAuthStatusDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _boolOrNull) bool? loggedIn
});




}
/// @nodoc
class _$ClaudeAuthStatusDtoCopyWithImpl<$Res>
    implements $ClaudeAuthStatusDtoCopyWith<$Res> {
  _$ClaudeAuthStatusDtoCopyWithImpl(this._self, this._then);

  final ClaudeAuthStatusDto _self;
  final $Res Function(ClaudeAuthStatusDto) _then;

/// Create a copy of ClaudeAuthStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loggedIn = freezed,}) {
  return _then(ClaudeAuthStatusDto(
loggedIn: freezed == loggedIn ? _self.loggedIn : loggedIn // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeAuthStatusDto implements ClaudeAuthStatusDto {
  const _ClaudeAuthStatusDto({@JsonKey(fromJson: _boolOrNull) required this.loggedIn});
  factory _ClaudeAuthStatusDto.fromJson(Map<String, dynamic> json) => _$ClaudeAuthStatusDtoFromJson(json);

@override@JsonKey(fromJson: _boolOrNull) final  bool? loggedIn;

/// Create a copy of ClaudeAuthStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeAuthStatusDtoCopyWith<_ClaudeAuthStatusDto> get copyWith => __$ClaudeAuthStatusDtoCopyWithImpl<_ClaudeAuthStatusDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeAuthStatusDto&&(identical(other.loggedIn, loggedIn) || other.loggedIn == loggedIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loggedIn);



}

/// @nodoc
abstract mixin class _$ClaudeAuthStatusDtoCopyWith<$Res> implements $ClaudeAuthStatusDtoCopyWith<$Res> {
  factory _$ClaudeAuthStatusDtoCopyWith(_ClaudeAuthStatusDto value, $Res Function(_ClaudeAuthStatusDto) _then) = __$ClaudeAuthStatusDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _boolOrNull) bool? loggedIn
});




}
/// @nodoc
class __$ClaudeAuthStatusDtoCopyWithImpl<$Res>
    implements _$ClaudeAuthStatusDtoCopyWith<$Res> {
  __$ClaudeAuthStatusDtoCopyWithImpl(this._self, this._then);

  final _ClaudeAuthStatusDto _self;
  final $Res Function(_ClaudeAuthStatusDto) _then;

/// Create a copy of ClaudeAuthStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loggedIn = freezed,}) {
  return _then(_ClaudeAuthStatusDto(
loggedIn: freezed == loggedIn ? _self.loggedIn : loggedIn // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
