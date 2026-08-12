// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_turn_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexTurnStartResponseDto {

 CodexTurnDto? get turn;
/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnStartResponseDtoCopyWith<CodexTurnStartResponseDto> get copyWith => _$CodexTurnStartResponseDtoCopyWithImpl<CodexTurnStartResponseDto>(this as CodexTurnStartResponseDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnStartResponseDto&&(identical(other.turn, turn) || other.turn == turn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,turn);

@override
String toString() {
  return 'CodexTurnStartResponseDto(turn: $turn)';
}


}

/// @nodoc
abstract mixin class $CodexTurnStartResponseDtoCopyWith<$Res>  {
  factory $CodexTurnStartResponseDtoCopyWith(CodexTurnStartResponseDto value, $Res Function(CodexTurnStartResponseDto) _then) = _$CodexTurnStartResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexTurnDto? turn
});


$CodexTurnDtoCopyWith<$Res>? get turn;

}
/// @nodoc
class _$CodexTurnStartResponseDtoCopyWithImpl<$Res>
    implements $CodexTurnStartResponseDtoCopyWith<$Res> {
  _$CodexTurnStartResponseDtoCopyWithImpl(this._self, this._then);

  final CodexTurnStartResponseDto _self;
  final $Res Function(CodexTurnStartResponseDto) _then;

/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? turn = freezed,}) {
  return _then(CodexTurnStartResponseDto(
turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,
  ));
}
/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexTurnStartResponseDto implements CodexTurnStartResponseDto {
  const _CodexTurnStartResponseDto({required this.turn});
  factory _CodexTurnStartResponseDto.fromJson(Map<String, dynamic> json) => _$CodexTurnStartResponseDtoFromJson(json);

@override final  CodexTurnDto? turn;

/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexTurnStartResponseDtoCopyWith<_CodexTurnStartResponseDto> get copyWith => __$CodexTurnStartResponseDtoCopyWithImpl<_CodexTurnStartResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTurnStartResponseDto&&(identical(other.turn, turn) || other.turn == turn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,turn);

@override
String toString() {
  return 'CodexTurnStartResponseDto(turn: $turn)';
}


}

/// @nodoc
abstract mixin class _$CodexTurnStartResponseDtoCopyWith<$Res> implements $CodexTurnStartResponseDtoCopyWith<$Res> {
  factory _$CodexTurnStartResponseDtoCopyWith(_CodexTurnStartResponseDto value, $Res Function(_CodexTurnStartResponseDto) _then) = __$CodexTurnStartResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexTurnDto? turn
});


@override $CodexTurnDtoCopyWith<$Res>? get turn;

}
/// @nodoc
class __$CodexTurnStartResponseDtoCopyWithImpl<$Res>
    implements _$CodexTurnStartResponseDtoCopyWith<$Res> {
  __$CodexTurnStartResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexTurnStartResponseDto _self;
  final $Res Function(_CodexTurnStartResponseDto) _then;

/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? turn = freezed,}) {
  return _then(_CodexTurnStartResponseDto(
turn: freezed == turn ? _self.turn : turn // ignore: cast_nullable_to_non_nullable
as CodexTurnDto?,
  ));
}

/// Create a copy of CodexTurnStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<$Res>? get turn {
    if (_self.turn == null) {
    return null;
  }

  return $CodexTurnDtoCopyWith<$Res>(_self.turn!, (value) {
    return _then(_self.copyWith(turn: value));
  });
}
}


/// @nodoc
mixin _$CodexTurnDto {

 String? get id;
/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnDtoCopyWith<CodexTurnDto> get copyWith => _$CodexTurnDtoCopyWithImpl<CodexTurnDto>(this as CodexTurnDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'CodexTurnDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $CodexTurnDtoCopyWith<$Res>  {
  factory $CodexTurnDtoCopyWith(CodexTurnDto value, $Res Function(CodexTurnDto) _then) = _$CodexTurnDtoCopyWithImpl;
@useResult
$Res call({
 String? id
});




}
/// @nodoc
class _$CodexTurnDtoCopyWithImpl<$Res>
    implements $CodexTurnDtoCopyWith<$Res> {
  _$CodexTurnDtoCopyWithImpl(this._self, this._then);

  final CodexTurnDto _self;
  final $Res Function(CodexTurnDto) _then;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,}) {
  return _then(CodexTurnDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexTurnDto implements CodexTurnDto {
  const _CodexTurnDto({required this.id});
  factory _CodexTurnDto.fromJson(Map<String, dynamic> json) => _$CodexTurnDtoFromJson(json);

@override final  String? id;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexTurnDtoCopyWith<_CodexTurnDto> get copyWith => __$CodexTurnDtoCopyWithImpl<_CodexTurnDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexTurnDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'CodexTurnDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$CodexTurnDtoCopyWith<$Res> implements $CodexTurnDtoCopyWith<$Res> {
  factory _$CodexTurnDtoCopyWith(_CodexTurnDto value, $Res Function(_CodexTurnDto) _then) = __$CodexTurnDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id
});




}
/// @nodoc
class __$CodexTurnDtoCopyWithImpl<$Res>
    implements _$CodexTurnDtoCopyWith<$Res> {
  __$CodexTurnDtoCopyWithImpl(this._self, this._then);

  final _CodexTurnDto _self;
  final $Res Function(_CodexTurnDto) _then;

/// Create a copy of CodexTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,}) {
  return _then(_CodexTurnDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
