// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_collaboration_mode_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CodexCollaborationModeDto {

 String get mode; CodexCollaborationModeSettingsDto get settings;
/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCollaborationModeDtoCopyWith<CodexCollaborationModeDto> get copyWith => _$CodexCollaborationModeDtoCopyWithImpl<CodexCollaborationModeDto>(this as CodexCollaborationModeDto, _$identity);

  /// Serializes this CodexCollaborationModeDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCollaborationModeDto&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,settings);

@override
String toString() {
  return 'CodexCollaborationModeDto(mode: $mode, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $CodexCollaborationModeDtoCopyWith<$Res>  {
  factory $CodexCollaborationModeDtoCopyWith(CodexCollaborationModeDto value, $Res Function(CodexCollaborationModeDto) _then) = _$CodexCollaborationModeDtoCopyWithImpl;
@useResult
$Res call({
 String mode, CodexCollaborationModeSettingsDto settings
});


$CodexCollaborationModeSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class _$CodexCollaborationModeDtoCopyWithImpl<$Res>
    implements $CodexCollaborationModeDtoCopyWith<$Res> {
  _$CodexCollaborationModeDtoCopyWithImpl(this._self, this._then);

  final CodexCollaborationModeDto _self;
  final $Res Function(CodexCollaborationModeDto) _then;

/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? settings = null,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CodexCollaborationModeSettingsDto,
  ));
}
/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexCollaborationModeSettingsDtoCopyWith<$Res> get settings {
  
  return $CodexCollaborationModeSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _CodexCollaborationModeDto implements CodexCollaborationModeDto {
  const _CodexCollaborationModeDto({required this.mode, required this.settings});
  

@override final  String mode;
@override final  CodexCollaborationModeSettingsDto settings;

/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexCollaborationModeDtoCopyWith<_CodexCollaborationModeDto> get copyWith => __$CodexCollaborationModeDtoCopyWithImpl<_CodexCollaborationModeDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexCollaborationModeDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexCollaborationModeDto&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,settings);

@override
String toString() {
  return 'CodexCollaborationModeDto(mode: $mode, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$CodexCollaborationModeDtoCopyWith<$Res> implements $CodexCollaborationModeDtoCopyWith<$Res> {
  factory _$CodexCollaborationModeDtoCopyWith(_CodexCollaborationModeDto value, $Res Function(_CodexCollaborationModeDto) _then) = __$CodexCollaborationModeDtoCopyWithImpl;
@override @useResult
$Res call({
 String mode, CodexCollaborationModeSettingsDto settings
});


@override $CodexCollaborationModeSettingsDtoCopyWith<$Res> get settings;

}
/// @nodoc
class __$CodexCollaborationModeDtoCopyWithImpl<$Res>
    implements _$CodexCollaborationModeDtoCopyWith<$Res> {
  __$CodexCollaborationModeDtoCopyWithImpl(this._self, this._then);

  final _CodexCollaborationModeDto _self;
  final $Res Function(_CodexCollaborationModeDto) _then;

/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? settings = null,}) {
  return _then(_CodexCollaborationModeDto(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as CodexCollaborationModeSettingsDto,
  ));
}

/// Create a copy of CodexCollaborationModeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexCollaborationModeSettingsDtoCopyWith<$Res> get settings {
  
  return $CodexCollaborationModeSettingsDtoCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

/// @nodoc
mixin _$CodexCollaborationModeSettingsDto {

 String get model;@JsonKey(name: "reasoning_effort") String? get reasoningEffort;@JsonKey(name: "developer_instructions") String? get developerInstructions;
/// Create a copy of CodexCollaborationModeSettingsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexCollaborationModeSettingsDtoCopyWith<CodexCollaborationModeSettingsDto> get copyWith => _$CodexCollaborationModeSettingsDtoCopyWithImpl<CodexCollaborationModeSettingsDto>(this as CodexCollaborationModeSettingsDto, _$identity);

  /// Serializes this CodexCollaborationModeSettingsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexCollaborationModeSettingsDto&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.developerInstructions, developerInstructions) || other.developerInstructions == developerInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,reasoningEffort,developerInstructions);

@override
String toString() {
  return 'CodexCollaborationModeSettingsDto(model: $model, reasoningEffort: $reasoningEffort, developerInstructions: $developerInstructions)';
}


}

/// @nodoc
abstract mixin class $CodexCollaborationModeSettingsDtoCopyWith<$Res>  {
  factory $CodexCollaborationModeSettingsDtoCopyWith(CodexCollaborationModeSettingsDto value, $Res Function(CodexCollaborationModeSettingsDto) _then) = _$CodexCollaborationModeSettingsDtoCopyWithImpl;
@useResult
$Res call({
 String model,@JsonKey(name: "reasoning_effort") String? reasoningEffort,@JsonKey(name: "developer_instructions") String? developerInstructions
});




}
/// @nodoc
class _$CodexCollaborationModeSettingsDtoCopyWithImpl<$Res>
    implements $CodexCollaborationModeSettingsDtoCopyWith<$Res> {
  _$CodexCollaborationModeSettingsDtoCopyWithImpl(this._self, this._then);

  final CodexCollaborationModeSettingsDto _self;
  final $Res Function(CodexCollaborationModeSettingsDto) _then;

/// Create a copy of CodexCollaborationModeSettingsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? reasoningEffort = freezed,Object? developerInstructions = freezed,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,developerInstructions: freezed == developerInstructions ? _self.developerInstructions : developerInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _CodexCollaborationModeSettingsDto implements CodexCollaborationModeSettingsDto {
  const _CodexCollaborationModeSettingsDto({required this.model, @JsonKey(name: "reasoning_effort") required this.reasoningEffort, @JsonKey(name: "developer_instructions") required this.developerInstructions});
  

@override final  String model;
@override@JsonKey(name: "reasoning_effort") final  String? reasoningEffort;
@override@JsonKey(name: "developer_instructions") final  String? developerInstructions;

/// Create a copy of CodexCollaborationModeSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexCollaborationModeSettingsDtoCopyWith<_CodexCollaborationModeSettingsDto> get copyWith => __$CodexCollaborationModeSettingsDtoCopyWithImpl<_CodexCollaborationModeSettingsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexCollaborationModeSettingsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexCollaborationModeSettingsDto&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.developerInstructions, developerInstructions) || other.developerInstructions == developerInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,reasoningEffort,developerInstructions);

@override
String toString() {
  return 'CodexCollaborationModeSettingsDto(model: $model, reasoningEffort: $reasoningEffort, developerInstructions: $developerInstructions)';
}


}

/// @nodoc
abstract mixin class _$CodexCollaborationModeSettingsDtoCopyWith<$Res> implements $CodexCollaborationModeSettingsDtoCopyWith<$Res> {
  factory _$CodexCollaborationModeSettingsDtoCopyWith(_CodexCollaborationModeSettingsDto value, $Res Function(_CodexCollaborationModeSettingsDto) _then) = __$CodexCollaborationModeSettingsDtoCopyWithImpl;
@override @useResult
$Res call({
 String model,@JsonKey(name: "reasoning_effort") String? reasoningEffort,@JsonKey(name: "developer_instructions") String? developerInstructions
});




}
/// @nodoc
class __$CodexCollaborationModeSettingsDtoCopyWithImpl<$Res>
    implements _$CodexCollaborationModeSettingsDtoCopyWith<$Res> {
  __$CodexCollaborationModeSettingsDtoCopyWithImpl(this._self, this._then);

  final _CodexCollaborationModeSettingsDto _self;
  final $Res Function(_CodexCollaborationModeSettingsDto) _then;

/// Create a copy of CodexCollaborationModeSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? reasoningEffort = freezed,Object? developerInstructions = freezed,}) {
  return _then(_CodexCollaborationModeSettingsDto(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,developerInstructions: freezed == developerInstructions ? _self.developerInstructions : developerInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
