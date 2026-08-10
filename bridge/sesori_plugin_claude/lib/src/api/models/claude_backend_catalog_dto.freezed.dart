// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_backend_catalog_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeBackendCatalogDto {

@JsonKey(fromJson: _commandsOrEmpty) List<ClaudeCommandDto> get commands;@JsonKey(fromJson: _modelsOrEmpty) List<ClaudeModelDto> get models;
/// Create a copy of ClaudeBackendCatalogDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeBackendCatalogDtoCopyWith<ClaudeBackendCatalogDto> get copyWith => _$ClaudeBackendCatalogDtoCopyWithImpl<ClaudeBackendCatalogDto>(this as ClaudeBackendCatalogDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeBackendCatalogDto&&const DeepCollectionEquality().equals(other.commands, commands)&&const DeepCollectionEquality().equals(other.models, models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(commands),const DeepCollectionEquality().hash(models));



}

/// @nodoc
abstract mixin class $ClaudeBackendCatalogDtoCopyWith<$Res>  {
  factory $ClaudeBackendCatalogDtoCopyWith(ClaudeBackendCatalogDto value, $Res Function(ClaudeBackendCatalogDto) _then) = _$ClaudeBackendCatalogDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _commandsOrEmpty) List<ClaudeCommandDto> commands,@JsonKey(fromJson: _modelsOrEmpty) List<ClaudeModelDto> models
});




}
/// @nodoc
class _$ClaudeBackendCatalogDtoCopyWithImpl<$Res>
    implements $ClaudeBackendCatalogDtoCopyWith<$Res> {
  _$ClaudeBackendCatalogDtoCopyWithImpl(this._self, this._then);

  final ClaudeBackendCatalogDto _self;
  final $Res Function(ClaudeBackendCatalogDto) _then;

/// Create a copy of ClaudeBackendCatalogDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commands = null,Object? models = null,}) {
  return _then(_self.copyWith(
commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<ClaudeCommandDto>,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<ClaudeModelDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeBackendCatalogDto implements ClaudeBackendCatalogDto {
  const _ClaudeBackendCatalogDto({@JsonKey(fromJson: _commandsOrEmpty) required final  List<ClaudeCommandDto> commands, @JsonKey(fromJson: _modelsOrEmpty) required final  List<ClaudeModelDto> models}): _commands = commands,_models = models;
  factory _ClaudeBackendCatalogDto.fromJson(Map<String, dynamic> json) => _$ClaudeBackendCatalogDtoFromJson(json);

 final  List<ClaudeCommandDto> _commands;
@override@JsonKey(fromJson: _commandsOrEmpty) List<ClaudeCommandDto> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}

 final  List<ClaudeModelDto> _models;
@override@JsonKey(fromJson: _modelsOrEmpty) List<ClaudeModelDto> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}


/// Create a copy of ClaudeBackendCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeBackendCatalogDtoCopyWith<_ClaudeBackendCatalogDto> get copyWith => __$ClaudeBackendCatalogDtoCopyWithImpl<_ClaudeBackendCatalogDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeBackendCatalogDto&&const DeepCollectionEquality().equals(other._commands, _commands)&&const DeepCollectionEquality().equals(other._models, _models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_commands),const DeepCollectionEquality().hash(_models));



}

/// @nodoc
abstract mixin class _$ClaudeBackendCatalogDtoCopyWith<$Res> implements $ClaudeBackendCatalogDtoCopyWith<$Res> {
  factory _$ClaudeBackendCatalogDtoCopyWith(_ClaudeBackendCatalogDto value, $Res Function(_ClaudeBackendCatalogDto) _then) = __$ClaudeBackendCatalogDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _commandsOrEmpty) List<ClaudeCommandDto> commands,@JsonKey(fromJson: _modelsOrEmpty) List<ClaudeModelDto> models
});




}
/// @nodoc
class __$ClaudeBackendCatalogDtoCopyWithImpl<$Res>
    implements _$ClaudeBackendCatalogDtoCopyWith<$Res> {
  __$ClaudeBackendCatalogDtoCopyWithImpl(this._self, this._then);

  final _ClaudeBackendCatalogDto _self;
  final $Res Function(_ClaudeBackendCatalogDto) _then;

/// Create a copy of ClaudeBackendCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commands = null,Object? models = null,}) {
  return _then(_ClaudeBackendCatalogDto(
commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<ClaudeCommandDto>,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<ClaudeModelDto>,
  ));
}


}


/// @nodoc
mixin _$ClaudeCommandDto {

@JsonKey(fromJson: _stringOrNull) String? get name;@JsonKey(fromJson: _stringOrNull) String? get description;@JsonKey(fromJson: _stringOrNull) String? get argumentHint;
/// Create a copy of ClaudeCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeCommandDtoCopyWith<ClaudeCommandDto> get copyWith => _$ClaudeCommandDtoCopyWithImpl<ClaudeCommandDto>(this as ClaudeCommandDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeCommandDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.argumentHint, argumentHint) || other.argumentHint == argumentHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,argumentHint);



}

/// @nodoc
abstract mixin class $ClaudeCommandDtoCopyWith<$Res>  {
  factory $ClaudeCommandDtoCopyWith(ClaudeCommandDto value, $Res Function(ClaudeCommandDto) _then) = _$ClaudeCommandDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _stringOrNull) String? argumentHint
});




}
/// @nodoc
class _$ClaudeCommandDtoCopyWithImpl<$Res>
    implements $ClaudeCommandDtoCopyWith<$Res> {
  _$ClaudeCommandDtoCopyWithImpl(this._self, this._then);

  final ClaudeCommandDto _self;
  final $Res Function(ClaudeCommandDto) _then;

/// Create a copy of ClaudeCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? description = freezed,Object? argumentHint = freezed,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,argumentHint: freezed == argumentHint ? _self.argumentHint : argumentHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeCommandDto implements ClaudeCommandDto {
  const _ClaudeCommandDto({@JsonKey(fromJson: _stringOrNull) required this.name, @JsonKey(fromJson: _stringOrNull) required this.description, @JsonKey(fromJson: _stringOrNull) required this.argumentHint});
  factory _ClaudeCommandDto.fromJson(Map<String, dynamic> json) => _$ClaudeCommandDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? name;
@override@JsonKey(fromJson: _stringOrNull) final  String? description;
@override@JsonKey(fromJson: _stringOrNull) final  String? argumentHint;

/// Create a copy of ClaudeCommandDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeCommandDtoCopyWith<_ClaudeCommandDto> get copyWith => __$ClaudeCommandDtoCopyWithImpl<_ClaudeCommandDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeCommandDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.argumentHint, argumentHint) || other.argumentHint == argumentHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,argumentHint);



}

/// @nodoc
abstract mixin class _$ClaudeCommandDtoCopyWith<$Res> implements $ClaudeCommandDtoCopyWith<$Res> {
  factory _$ClaudeCommandDtoCopyWith(_ClaudeCommandDto value, $Res Function(_ClaudeCommandDto) _then) = __$ClaudeCommandDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _stringOrNull) String? argumentHint
});




}
/// @nodoc
class __$ClaudeCommandDtoCopyWithImpl<$Res>
    implements _$ClaudeCommandDtoCopyWith<$Res> {
  __$ClaudeCommandDtoCopyWithImpl(this._self, this._then);

  final _ClaudeCommandDto _self;
  final $Res Function(_ClaudeCommandDto) _then;

/// Create a copy of ClaudeCommandDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? description = freezed,Object? argumentHint = freezed,}) {
  return _then(_ClaudeCommandDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,argumentHint: freezed == argumentHint ? _self.argumentHint : argumentHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ClaudeModelDto {

@JsonKey(fromJson: _stringOrNull) String? get value;@JsonKey(fromJson: _stringOrNull) String? get resolvedModel;@JsonKey(fromJson: _stringOrNull) String? get displayName;@JsonKey(fromJson: _boolOrNull) bool? get supportsEffort;@JsonKey(fromJson: _stringsOrEmpty) List<String> get supportedEffortLevels;
/// Create a copy of ClaudeModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeModelDtoCopyWith<ClaudeModelDto> get copyWith => _$ClaudeModelDtoCopyWithImpl<ClaudeModelDto>(this as ClaudeModelDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeModelDto&&(identical(other.value, value) || other.value == value)&&(identical(other.resolvedModel, resolvedModel) || other.resolvedModel == resolvedModel)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.supportsEffort, supportsEffort) || other.supportsEffort == supportsEffort)&&const DeepCollectionEquality().equals(other.supportedEffortLevels, supportedEffortLevels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,resolvedModel,displayName,supportsEffort,const DeepCollectionEquality().hash(supportedEffortLevels));



}

/// @nodoc
abstract mixin class $ClaudeModelDtoCopyWith<$Res>  {
  factory $ClaudeModelDtoCopyWith(ClaudeModelDto value, $Res Function(ClaudeModelDto) _then) = _$ClaudeModelDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? value,@JsonKey(fromJson: _stringOrNull) String? resolvedModel,@JsonKey(fromJson: _stringOrNull) String? displayName,@JsonKey(fromJson: _boolOrNull) bool? supportsEffort,@JsonKey(fromJson: _stringsOrEmpty) List<String> supportedEffortLevels
});




}
/// @nodoc
class _$ClaudeModelDtoCopyWithImpl<$Res>
    implements $ClaudeModelDtoCopyWith<$Res> {
  _$ClaudeModelDtoCopyWithImpl(this._self, this._then);

  final ClaudeModelDto _self;
  final $Res Function(ClaudeModelDto) _then;

/// Create a copy of ClaudeModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = freezed,Object? resolvedModel = freezed,Object? displayName = freezed,Object? supportsEffort = freezed,Object? supportedEffortLevels = null,}) {
  return _then(_self.copyWith(
value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,resolvedModel: freezed == resolvedModel ? _self.resolvedModel : resolvedModel // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,supportsEffort: freezed == supportsEffort ? _self.supportsEffort : supportsEffort // ignore: cast_nullable_to_non_nullable
as bool?,supportedEffortLevels: null == supportedEffortLevels ? _self.supportedEffortLevels : supportedEffortLevels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeModelDto implements ClaudeModelDto {
  const _ClaudeModelDto({@JsonKey(fromJson: _stringOrNull) required this.value, @JsonKey(fromJson: _stringOrNull) required this.resolvedModel, @JsonKey(fromJson: _stringOrNull) required this.displayName, @JsonKey(fromJson: _boolOrNull) required this.supportsEffort, @JsonKey(fromJson: _stringsOrEmpty) required final  List<String> supportedEffortLevels}): _supportedEffortLevels = supportedEffortLevels;
  factory _ClaudeModelDto.fromJson(Map<String, dynamic> json) => _$ClaudeModelDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? value;
@override@JsonKey(fromJson: _stringOrNull) final  String? resolvedModel;
@override@JsonKey(fromJson: _stringOrNull) final  String? displayName;
@override@JsonKey(fromJson: _boolOrNull) final  bool? supportsEffort;
 final  List<String> _supportedEffortLevels;
@override@JsonKey(fromJson: _stringsOrEmpty) List<String> get supportedEffortLevels {
  if (_supportedEffortLevels is EqualUnmodifiableListView) return _supportedEffortLevels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedEffortLevels);
}


/// Create a copy of ClaudeModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeModelDtoCopyWith<_ClaudeModelDto> get copyWith => __$ClaudeModelDtoCopyWithImpl<_ClaudeModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeModelDto&&(identical(other.value, value) || other.value == value)&&(identical(other.resolvedModel, resolvedModel) || other.resolvedModel == resolvedModel)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.supportsEffort, supportsEffort) || other.supportsEffort == supportsEffort)&&const DeepCollectionEquality().equals(other._supportedEffortLevels, _supportedEffortLevels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,resolvedModel,displayName,supportsEffort,const DeepCollectionEquality().hash(_supportedEffortLevels));



}

/// @nodoc
abstract mixin class _$ClaudeModelDtoCopyWith<$Res> implements $ClaudeModelDtoCopyWith<$Res> {
  factory _$ClaudeModelDtoCopyWith(_ClaudeModelDto value, $Res Function(_ClaudeModelDto) _then) = __$ClaudeModelDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? value,@JsonKey(fromJson: _stringOrNull) String? resolvedModel,@JsonKey(fromJson: _stringOrNull) String? displayName,@JsonKey(fromJson: _boolOrNull) bool? supportsEffort,@JsonKey(fromJson: _stringsOrEmpty) List<String> supportedEffortLevels
});




}
/// @nodoc
class __$ClaudeModelDtoCopyWithImpl<$Res>
    implements _$ClaudeModelDtoCopyWith<$Res> {
  __$ClaudeModelDtoCopyWithImpl(this._self, this._then);

  final _ClaudeModelDto _self;
  final $Res Function(_ClaudeModelDto) _then;

/// Create a copy of ClaudeModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = freezed,Object? resolvedModel = freezed,Object? displayName = freezed,Object? supportsEffort = freezed,Object? supportedEffortLevels = null,}) {
  return _then(_ClaudeModelDto(
value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,resolvedModel: freezed == resolvedModel ? _self.resolvedModel : resolvedModel // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,supportsEffort: freezed == supportsEffort ? _self.supportsEffort : supportsEffort // ignore: cast_nullable_to_non_nullable
as bool?,supportedEffortLevels: null == supportedEffortLevels ? _self._supportedEffortLevels : supportedEffortLevels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
