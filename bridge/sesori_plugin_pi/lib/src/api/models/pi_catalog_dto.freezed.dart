// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_catalog_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PiCatalogModelDto {

@JsonKey(fromJson: _stringOrNull) String? get provider;@JsonKey(fromJson: _stringOrNull) String? get id;@JsonKey(fromJson: _stringOrNull) String? get name;@JsonKey(fromJson: _boolOrFalse) bool get reasoning;@JsonKey(fromJson: _stringList) List<String> get input;
/// Create a copy of PiCatalogModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCatalogModelDtoCopyWith<PiCatalogModelDto> get copyWith => _$PiCatalogModelDtoCopyWithImpl<PiCatalogModelDto>(this as PiCatalogModelDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCatalogModelDto&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&const DeepCollectionEquality().equals(other.input, input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,id,name,reasoning,const DeepCollectionEquality().hash(input));



}

/// @nodoc
abstract mixin class $PiCatalogModelDtoCopyWith<$Res>  {
  factory $PiCatalogModelDtoCopyWith(PiCatalogModelDto value, $Res Function(PiCatalogModelDto) _then) = _$PiCatalogModelDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? provider,@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _boolOrFalse) bool reasoning,@JsonKey(fromJson: _stringList) List<String> input
});




}
/// @nodoc
class _$PiCatalogModelDtoCopyWithImpl<$Res>
    implements $PiCatalogModelDtoCopyWith<$Res> {
  _$PiCatalogModelDtoCopyWithImpl(this._self, this._then);

  final PiCatalogModelDto _self;
  final $Res Function(PiCatalogModelDto) _then;

/// Create a copy of PiCatalogModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = freezed,Object? id = freezed,Object? name = freezed,Object? reasoning = null,Object? input = null,}) {
  return _then(PiCatalogModelDto(
provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiCatalogModelDto implements PiCatalogModelDto {
  const _PiCatalogModelDto({@JsonKey(fromJson: _stringOrNull) required this.provider, @JsonKey(fromJson: _stringOrNull) required this.id, @JsonKey(fromJson: _stringOrNull) required this.name, @JsonKey(fromJson: _boolOrFalse) required this.reasoning, @JsonKey(fromJson: _stringList) required  List<String> input}): _input = input;
  factory _PiCatalogModelDto.fromJson(Map<String, dynamic> json) => _$PiCatalogModelDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? provider;
@override@JsonKey(fromJson: _stringOrNull) final  String? id;
@override@JsonKey(fromJson: _stringOrNull) final  String? name;
@override@JsonKey(fromJson: _boolOrFalse) final  bool reasoning;
 final  List<String> _input;
@override@JsonKey(fromJson: _stringList) List<String> get input {
  if (_input is EqualUnmodifiableListView) return _input;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_input);
}


/// Create a copy of PiCatalogModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiCatalogModelDtoCopyWith<_PiCatalogModelDto> get copyWith => __$PiCatalogModelDtoCopyWithImpl<_PiCatalogModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiCatalogModelDto&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&const DeepCollectionEquality().equals(other._input, _input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,id,name,reasoning,const DeepCollectionEquality().hash(_input));



}

/// @nodoc
abstract mixin class _$PiCatalogModelDtoCopyWith<$Res> implements $PiCatalogModelDtoCopyWith<$Res> {
  factory _$PiCatalogModelDtoCopyWith(_PiCatalogModelDto value, $Res Function(_PiCatalogModelDto) _then) = __$PiCatalogModelDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? provider,@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _boolOrFalse) bool reasoning,@JsonKey(fromJson: _stringList) List<String> input
});




}
/// @nodoc
class __$PiCatalogModelDtoCopyWithImpl<$Res>
    implements _$PiCatalogModelDtoCopyWith<$Res> {
  __$PiCatalogModelDtoCopyWithImpl(this._self, this._then);

  final _PiCatalogModelDto _self;
  final $Res Function(_PiCatalogModelDto) _then;

/// Create a copy of PiCatalogModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = freezed,Object? id = freezed,Object? name = freezed,Object? reasoning = null,Object? input = null,}) {
  return _then(_PiCatalogModelDto(
provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool,input: null == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$PiStateCatalogDto {

@JsonKey(fromJson: _modelOrNull) PiCatalogModelDto? get model;
/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiStateCatalogDtoCopyWith<PiStateCatalogDto> get copyWith => _$PiStateCatalogDtoCopyWithImpl<PiStateCatalogDto>(this as PiStateCatalogDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiStateCatalogDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);



}

/// @nodoc
abstract mixin class $PiStateCatalogDtoCopyWith<$Res>  {
  factory $PiStateCatalogDtoCopyWith(PiStateCatalogDto value, $Res Function(PiStateCatalogDto) _then) = _$PiStateCatalogDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _modelOrNull) PiCatalogModelDto? model
});


$PiCatalogModelDtoCopyWith<$Res>? get model;

}
/// @nodoc
class _$PiStateCatalogDtoCopyWithImpl<$Res>
    implements $PiStateCatalogDtoCopyWith<$Res> {
  _$PiStateCatalogDtoCopyWithImpl(this._self, this._then);

  final PiStateCatalogDto _self;
  final $Res Function(PiStateCatalogDto) _then;

/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = freezed,}) {
  return _then(PiStateCatalogDto(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PiCatalogModelDto?,
  ));
}
/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiCatalogModelDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PiCatalogModelDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiStateCatalogDto implements PiStateCatalogDto {
  const _PiStateCatalogDto({@JsonKey(fromJson: _modelOrNull) required this.model});
  factory _PiStateCatalogDto.fromJson(Map<String, dynamic> json) => _$PiStateCatalogDtoFromJson(json);

@override@JsonKey(fromJson: _modelOrNull) final  PiCatalogModelDto? model;

/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiStateCatalogDtoCopyWith<_PiStateCatalogDto> get copyWith => __$PiStateCatalogDtoCopyWithImpl<_PiStateCatalogDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiStateCatalogDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);



}

/// @nodoc
abstract mixin class _$PiStateCatalogDtoCopyWith<$Res> implements $PiStateCatalogDtoCopyWith<$Res> {
  factory _$PiStateCatalogDtoCopyWith(_PiStateCatalogDto value, $Res Function(_PiStateCatalogDto) _then) = __$PiStateCatalogDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _modelOrNull) PiCatalogModelDto? model
});


@override $PiCatalogModelDtoCopyWith<$Res>? get model;

}
/// @nodoc
class __$PiStateCatalogDtoCopyWithImpl<$Res>
    implements _$PiStateCatalogDtoCopyWith<$Res> {
  __$PiStateCatalogDtoCopyWithImpl(this._self, this._then);

  final _PiStateCatalogDto _self;
  final $Res Function(_PiStateCatalogDto) _then;

/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = freezed,}) {
  return _then(_PiStateCatalogDto(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PiCatalogModelDto?,
  ));
}

/// Create a copy of PiStateCatalogDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiCatalogModelDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PiCatalogModelDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$PiAvailableModelsDto {

@JsonKey(fromJson: _modelList) List<PiCatalogModelDto> get models;
/// Create a copy of PiAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiAvailableModelsDtoCopyWith<PiAvailableModelsDto> get copyWith => _$PiAvailableModelsDtoCopyWithImpl<PiAvailableModelsDto>(this as PiAvailableModelsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiAvailableModelsDto&&const DeepCollectionEquality().equals(other.models, models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(models));



}

/// @nodoc
abstract mixin class $PiAvailableModelsDtoCopyWith<$Res>  {
  factory $PiAvailableModelsDtoCopyWith(PiAvailableModelsDto value, $Res Function(PiAvailableModelsDto) _then) = _$PiAvailableModelsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _modelList) List<PiCatalogModelDto> models
});




}
/// @nodoc
class _$PiAvailableModelsDtoCopyWithImpl<$Res>
    implements $PiAvailableModelsDtoCopyWith<$Res> {
  _$PiAvailableModelsDtoCopyWithImpl(this._self, this._then);

  final PiAvailableModelsDto _self;
  final $Res Function(PiAvailableModelsDto) _then;

/// Create a copy of PiAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? models = null,}) {
  return _then(PiAvailableModelsDto(
models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<PiCatalogModelDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiAvailableModelsDto implements PiAvailableModelsDto {
  const _PiAvailableModelsDto({@JsonKey(fromJson: _modelList) required  List<PiCatalogModelDto> models}): _models = models;
  factory _PiAvailableModelsDto.fromJson(Map<String, dynamic> json) => _$PiAvailableModelsDtoFromJson(json);

 final  List<PiCatalogModelDto> _models;
@override@JsonKey(fromJson: _modelList) List<PiCatalogModelDto> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}


/// Create a copy of PiAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiAvailableModelsDtoCopyWith<_PiAvailableModelsDto> get copyWith => __$PiAvailableModelsDtoCopyWithImpl<_PiAvailableModelsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiAvailableModelsDto&&const DeepCollectionEquality().equals(other._models, _models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_models));



}

/// @nodoc
abstract mixin class _$PiAvailableModelsDtoCopyWith<$Res> implements $PiAvailableModelsDtoCopyWith<$Res> {
  factory _$PiAvailableModelsDtoCopyWith(_PiAvailableModelsDto value, $Res Function(_PiAvailableModelsDto) _then) = __$PiAvailableModelsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _modelList) List<PiCatalogModelDto> models
});




}
/// @nodoc
class __$PiAvailableModelsDtoCopyWithImpl<$Res>
    implements _$PiAvailableModelsDtoCopyWith<$Res> {
  __$PiAvailableModelsDtoCopyWithImpl(this._self, this._then);

  final _PiAvailableModelsDto _self;
  final $Res Function(_PiAvailableModelsDto) _then;

/// Create a copy of PiAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? models = null,}) {
  return _then(_PiAvailableModelsDto(
models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PiCatalogModelDto>,
  ));
}


}


/// @nodoc
mixin _$PiThinkingLevelsDto {

@JsonKey(fromJson: _stringList) List<String> get levels;
/// Create a copy of PiThinkingLevelsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiThinkingLevelsDtoCopyWith<PiThinkingLevelsDto> get copyWith => _$PiThinkingLevelsDtoCopyWithImpl<PiThinkingLevelsDto>(this as PiThinkingLevelsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiThinkingLevelsDto&&const DeepCollectionEquality().equals(other.levels, levels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(levels));



}

/// @nodoc
abstract mixin class $PiThinkingLevelsDtoCopyWith<$Res>  {
  factory $PiThinkingLevelsDtoCopyWith(PiThinkingLevelsDto value, $Res Function(PiThinkingLevelsDto) _then) = _$PiThinkingLevelsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringList) List<String> levels
});




}
/// @nodoc
class _$PiThinkingLevelsDtoCopyWithImpl<$Res>
    implements $PiThinkingLevelsDtoCopyWith<$Res> {
  _$PiThinkingLevelsDtoCopyWithImpl(this._self, this._then);

  final PiThinkingLevelsDto _self;
  final $Res Function(PiThinkingLevelsDto) _then;

/// Create a copy of PiThinkingLevelsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? levels = null,}) {
  return _then(PiThinkingLevelsDto(
levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiThinkingLevelsDto implements PiThinkingLevelsDto {
  const _PiThinkingLevelsDto({@JsonKey(fromJson: _stringList) required  List<String> levels}): _levels = levels;
  factory _PiThinkingLevelsDto.fromJson(Map<String, dynamic> json) => _$PiThinkingLevelsDtoFromJson(json);

 final  List<String> _levels;
@override@JsonKey(fromJson: _stringList) List<String> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}


/// Create a copy of PiThinkingLevelsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiThinkingLevelsDtoCopyWith<_PiThinkingLevelsDto> get copyWith => __$PiThinkingLevelsDtoCopyWithImpl<_PiThinkingLevelsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiThinkingLevelsDto&&const DeepCollectionEquality().equals(other._levels, _levels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_levels));



}

/// @nodoc
abstract mixin class _$PiThinkingLevelsDtoCopyWith<$Res> implements $PiThinkingLevelsDtoCopyWith<$Res> {
  factory _$PiThinkingLevelsDtoCopyWith(_PiThinkingLevelsDto value, $Res Function(_PiThinkingLevelsDto) _then) = __$PiThinkingLevelsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringList) List<String> levels
});




}
/// @nodoc
class __$PiThinkingLevelsDtoCopyWithImpl<$Res>
    implements _$PiThinkingLevelsDtoCopyWith<$Res> {
  __$PiThinkingLevelsDtoCopyWithImpl(this._self, this._then);

  final _PiThinkingLevelsDto _self;
  final $Res Function(_PiThinkingLevelsDto) _then;

/// Create a copy of PiThinkingLevelsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? levels = null,}) {
  return _then(_PiThinkingLevelsDto(
levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$PiCatalogCommandDto {

@JsonKey(fromJson: _stringOrNull) String? get name;@JsonKey(fromJson: _stringOrNull) String? get description;@JsonKey(fromJson: _commandSource) PiCatalogCommandSource get source;@JsonKey(name: "sourceInfo", fromJson: _commandSourcePath) String? get sourcePath;
/// Create a copy of PiCatalogCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCatalogCommandDtoCopyWith<PiCatalogCommandDto> get copyWith => _$PiCatalogCommandDtoCopyWithImpl<PiCatalogCommandDto>(this as PiCatalogCommandDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCatalogCommandDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourcePath, sourcePath) || other.sourcePath == sourcePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,sourcePath);



}

/// @nodoc
abstract mixin class $PiCatalogCommandDtoCopyWith<$Res>  {
  factory $PiCatalogCommandDtoCopyWith(PiCatalogCommandDto value, $Res Function(PiCatalogCommandDto) _then) = _$PiCatalogCommandDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _commandSource) PiCatalogCommandSource source,@JsonKey(name: "sourceInfo", fromJson: _commandSourcePath) String? sourcePath
});




}
/// @nodoc
class _$PiCatalogCommandDtoCopyWithImpl<$Res>
    implements $PiCatalogCommandDtoCopyWith<$Res> {
  _$PiCatalogCommandDtoCopyWithImpl(this._self, this._then);

  final PiCatalogCommandDto _self;
  final $Res Function(PiCatalogCommandDto) _then;

/// Create a copy of PiCatalogCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? description = freezed,Object? source = null,Object? sourcePath = freezed,}) {
  return _then(PiCatalogCommandDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PiCatalogCommandSource,sourcePath: freezed == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiCatalogCommandDto implements PiCatalogCommandDto {
  const _PiCatalogCommandDto({@JsonKey(fromJson: _stringOrNull) required this.name, @JsonKey(fromJson: _stringOrNull) required this.description, @JsonKey(fromJson: _commandSource) required this.source, @JsonKey(name: "sourceInfo", fromJson: _commandSourcePath) required this.sourcePath});
  factory _PiCatalogCommandDto.fromJson(Map<String, dynamic> json) => _$PiCatalogCommandDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? name;
@override@JsonKey(fromJson: _stringOrNull) final  String? description;
@override@JsonKey(fromJson: _commandSource) final  PiCatalogCommandSource source;
@override@JsonKey(name: "sourceInfo", fromJson: _commandSourcePath) final  String? sourcePath;

/// Create a copy of PiCatalogCommandDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiCatalogCommandDtoCopyWith<_PiCatalogCommandDto> get copyWith => __$PiCatalogCommandDtoCopyWithImpl<_PiCatalogCommandDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiCatalogCommandDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourcePath, sourcePath) || other.sourcePath == sourcePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,sourcePath);



}

/// @nodoc
abstract mixin class _$PiCatalogCommandDtoCopyWith<$Res> implements $PiCatalogCommandDtoCopyWith<$Res> {
  factory _$PiCatalogCommandDtoCopyWith(_PiCatalogCommandDto value, $Res Function(_PiCatalogCommandDto) _then) = __$PiCatalogCommandDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? name,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _commandSource) PiCatalogCommandSource source,@JsonKey(name: "sourceInfo", fromJson: _commandSourcePath) String? sourcePath
});




}
/// @nodoc
class __$PiCatalogCommandDtoCopyWithImpl<$Res>
    implements _$PiCatalogCommandDtoCopyWith<$Res> {
  __$PiCatalogCommandDtoCopyWithImpl(this._self, this._then);

  final _PiCatalogCommandDto _self;
  final $Res Function(_PiCatalogCommandDto) _then;

/// Create a copy of PiCatalogCommandDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? description = freezed,Object? source = null,Object? sourcePath = freezed,}) {
  return _then(_PiCatalogCommandDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PiCatalogCommandSource,sourcePath: freezed == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PiCommandsDto {

@JsonKey(fromJson: _commandList) List<PiCatalogCommandDto> get commands;
/// Create a copy of PiCommandsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCommandsDtoCopyWith<PiCommandsDto> get copyWith => _$PiCommandsDtoCopyWithImpl<PiCommandsDto>(this as PiCommandsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCommandsDto&&const DeepCollectionEquality().equals(other.commands, commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(commands));



}

/// @nodoc
abstract mixin class $PiCommandsDtoCopyWith<$Res>  {
  factory $PiCommandsDtoCopyWith(PiCommandsDto value, $Res Function(PiCommandsDto) _then) = _$PiCommandsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _commandList) List<PiCatalogCommandDto> commands
});




}
/// @nodoc
class _$PiCommandsDtoCopyWithImpl<$Res>
    implements $PiCommandsDtoCopyWith<$Res> {
  _$PiCommandsDtoCopyWithImpl(this._self, this._then);

  final PiCommandsDto _self;
  final $Res Function(PiCommandsDto) _then;

/// Create a copy of PiCommandsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commands = null,}) {
  return _then(PiCommandsDto(
commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<PiCatalogCommandDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiCommandsDto implements PiCommandsDto {
  const _PiCommandsDto({@JsonKey(fromJson: _commandList) required  List<PiCatalogCommandDto> commands}): _commands = commands;
  factory _PiCommandsDto.fromJson(Map<String, dynamic> json) => _$PiCommandsDtoFromJson(json);

 final  List<PiCatalogCommandDto> _commands;
@override@JsonKey(fromJson: _commandList) List<PiCatalogCommandDto> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}


/// Create a copy of PiCommandsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiCommandsDtoCopyWith<_PiCommandsDto> get copyWith => __$PiCommandsDtoCopyWithImpl<_PiCommandsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiCommandsDto&&const DeepCollectionEquality().equals(other._commands, _commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_commands));



}

/// @nodoc
abstract mixin class _$PiCommandsDtoCopyWith<$Res> implements $PiCommandsDtoCopyWith<$Res> {
  factory _$PiCommandsDtoCopyWith(_PiCommandsDto value, $Res Function(_PiCommandsDto) _then) = __$PiCommandsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _commandList) List<PiCatalogCommandDto> commands
});




}
/// @nodoc
class __$PiCommandsDtoCopyWithImpl<$Res>
    implements _$PiCommandsDtoCopyWith<$Res> {
  __$PiCommandsDtoCopyWithImpl(this._self, this._then);

  final _PiCommandsDto _self;
  final $Res Function(_PiCommandsDto) _then;

/// Create a copy of PiCommandsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commands = null,}) {
  return _then(_PiCommandsDto(
commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<PiCatalogCommandDto>,
  ));
}


}

// dart format on
