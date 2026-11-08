// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_config_read_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexConfigReadResponseDto {

 CodexEffectiveConfigDto get config;
/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexConfigReadResponseDtoCopyWith<CodexConfigReadResponseDto> get copyWith => _$CodexConfigReadResponseDtoCopyWithImpl<CodexConfigReadResponseDto>(this as CodexConfigReadResponseDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexConfigReadResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexConfigReadResponseDto&&(identical(other.config, _this.config) || other.config == _this.config));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexConfigReadResponseDto;
  return Object.hash(runtimeType,_this.config);
}

@override
String toString() {
  final _this = this as CodexConfigReadResponseDto;
  return 'CodexConfigReadResponseDto(config: ${_this.config})';
}


}

/// @nodoc
abstract mixin class $CodexConfigReadResponseDtoCopyWith<$Res>  {
  factory $CodexConfigReadResponseDtoCopyWith(CodexConfigReadResponseDto value, $Res Function(CodexConfigReadResponseDto) _then) = _$CodexConfigReadResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexEffectiveConfigDto config
});


$CodexEffectiveConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class _$CodexConfigReadResponseDtoCopyWithImpl<$Res>
    implements $CodexConfigReadResponseDtoCopyWith<$Res> {
  _$CodexConfigReadResponseDtoCopyWithImpl(this._self, this._then);

  final CodexConfigReadResponseDto _self;
  final $Res Function(CodexConfigReadResponseDto) _then;

/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? config = null,}) {
  return _then(CodexConfigReadResponseDto(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CodexEffectiveConfigDto,
  ));
}
/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexEffectiveConfigDtoCopyWith<$Res> get config {
  
  return $CodexEffectiveConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexConfigReadResponseDto implements CodexConfigReadResponseDto {
  const _CodexConfigReadResponseDto({required this.config});
  factory _CodexConfigReadResponseDto.fromJson(Map<String, dynamic> json) => _$CodexConfigReadResponseDtoFromJson(json);

@override final  CodexEffectiveConfigDto config;

/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexConfigReadResponseDtoCopyWith<_CodexConfigReadResponseDto> get copyWith => __$CodexConfigReadResponseDtoCopyWithImpl<_CodexConfigReadResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexConfigReadResponseDto&&(identical(other.config, config) || other.config == config));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,config);
}

@override
String toString() {
    return 'CodexConfigReadResponseDto(config: $config)';
}


}

/// @nodoc
abstract mixin class _$CodexConfigReadResponseDtoCopyWith<$Res> implements $CodexConfigReadResponseDtoCopyWith<$Res> {
  factory _$CodexConfigReadResponseDtoCopyWith(_CodexConfigReadResponseDto value, $Res Function(_CodexConfigReadResponseDto) _then) = __$CodexConfigReadResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexEffectiveConfigDto config
});


@override $CodexEffectiveConfigDtoCopyWith<$Res> get config;

}
/// @nodoc
class __$CodexConfigReadResponseDtoCopyWithImpl<$Res>
    implements _$CodexConfigReadResponseDtoCopyWith<$Res> {
  __$CodexConfigReadResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexConfigReadResponseDto _self;
  final $Res Function(_CodexConfigReadResponseDto) _then;

/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? config = null,}) {
  return _then(_CodexConfigReadResponseDto(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as CodexEffectiveConfigDto,
  ));
}

/// Create a copy of CodexConfigReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexEffectiveConfigDtoCopyWith<$Res> get config {
  
  return $CodexEffectiveConfigDtoCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// @nodoc
mixin _$CodexEffectiveConfigDto {

@JsonKey(name: "developer_instructions") String? get developerInstructions;
/// Create a copy of CodexEffectiveConfigDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexEffectiveConfigDtoCopyWith<CodexEffectiveConfigDto> get copyWith => _$CodexEffectiveConfigDtoCopyWithImpl<CodexEffectiveConfigDto>(this as CodexEffectiveConfigDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexEffectiveConfigDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexEffectiveConfigDto&&(identical(other.developerInstructions, _this.developerInstructions) || other.developerInstructions == _this.developerInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexEffectiveConfigDto;
  return Object.hash(runtimeType,_this.developerInstructions);
}

@override
String toString() {
  final _this = this as CodexEffectiveConfigDto;
  return 'CodexEffectiveConfigDto(developerInstructions: ${_this.developerInstructions})';
}


}

/// @nodoc
abstract mixin class $CodexEffectiveConfigDtoCopyWith<$Res>  {
  factory $CodexEffectiveConfigDtoCopyWith(CodexEffectiveConfigDto value, $Res Function(CodexEffectiveConfigDto) _then) = _$CodexEffectiveConfigDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "developer_instructions") String? developerInstructions
});




}
/// @nodoc
class _$CodexEffectiveConfigDtoCopyWithImpl<$Res>
    implements $CodexEffectiveConfigDtoCopyWith<$Res> {
  _$CodexEffectiveConfigDtoCopyWithImpl(this._self, this._then);

  final CodexEffectiveConfigDto _self;
  final $Res Function(CodexEffectiveConfigDto) _then;

/// Create a copy of CodexEffectiveConfigDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? developerInstructions = freezed,}) {
  return _then(CodexEffectiveConfigDto(
developerInstructions: freezed == developerInstructions ? _self.developerInstructions : developerInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexEffectiveConfigDto implements CodexEffectiveConfigDto {
  const _CodexEffectiveConfigDto({@JsonKey(name: "developer_instructions") required this.developerInstructions});
  factory _CodexEffectiveConfigDto.fromJson(Map<String, dynamic> json) => _$CodexEffectiveConfigDtoFromJson(json);

@override@JsonKey(name: "developer_instructions") final  String? developerInstructions;

/// Create a copy of CodexEffectiveConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexEffectiveConfigDtoCopyWith<_CodexEffectiveConfigDto> get copyWith => __$CodexEffectiveConfigDtoCopyWithImpl<_CodexEffectiveConfigDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexEffectiveConfigDto&&(identical(other.developerInstructions, developerInstructions) || other.developerInstructions == developerInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,developerInstructions);
}

@override
String toString() {
    return 'CodexEffectiveConfigDto(developerInstructions: $developerInstructions)';
}


}

/// @nodoc
abstract mixin class _$CodexEffectiveConfigDtoCopyWith<$Res> implements $CodexEffectiveConfigDtoCopyWith<$Res> {
  factory _$CodexEffectiveConfigDtoCopyWith(_CodexEffectiveConfigDto value, $Res Function(_CodexEffectiveConfigDto) _then) = __$CodexEffectiveConfigDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "developer_instructions") String? developerInstructions
});




}
/// @nodoc
class __$CodexEffectiveConfigDtoCopyWithImpl<$Res>
    implements _$CodexEffectiveConfigDtoCopyWith<$Res> {
  __$CodexEffectiveConfigDtoCopyWithImpl(this._self, this._then);

  final _CodexEffectiveConfigDto _self;
  final $Res Function(_CodexEffectiveConfigDto) _then;

/// Create a copy of CodexEffectiveConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? developerInstructions = freezed,}) {
  return _then(_CodexEffectiveConfigDto(
developerInstructions: freezed == developerInstructions ? _self.developerInstructions : developerInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
