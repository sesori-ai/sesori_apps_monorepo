// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cursor_available_models_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CursorAvailableModelsDto {

 List<CursorAvailableModelDto> get models;
/// Create a copy of CursorAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorAvailableModelsDtoCopyWith<CursorAvailableModelsDto> get copyWith => _$CursorAvailableModelsDtoCopyWithImpl<CursorAvailableModelsDto>(this as CursorAvailableModelsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorAvailableModelsDto&&const DeepCollectionEquality().equals(other.models, models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(models));

@override
String toString() {
  return 'CursorAvailableModelsDto(models: $models)';
}


}

/// @nodoc
abstract mixin class $CursorAvailableModelsDtoCopyWith<$Res>  {
  factory $CursorAvailableModelsDtoCopyWith(CursorAvailableModelsDto value, $Res Function(CursorAvailableModelsDto) _then) = _$CursorAvailableModelsDtoCopyWithImpl;
@useResult
$Res call({
 List<CursorAvailableModelDto> models
});




}
/// @nodoc
class _$CursorAvailableModelsDtoCopyWithImpl<$Res>
    implements $CursorAvailableModelsDtoCopyWith<$Res> {
  _$CursorAvailableModelsDtoCopyWithImpl(this._self, this._then);

  final CursorAvailableModelsDto _self;
  final $Res Function(CursorAvailableModelsDto) _then;

/// Create a copy of CursorAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? models = null,}) {
  return _then(_self.copyWith(
models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<CursorAvailableModelDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorAvailableModelsDto implements CursorAvailableModelsDto {
  const _CursorAvailableModelsDto({final  List<CursorAvailableModelDto> models = const <CursorAvailableModelDto>[]}): _models = models;
  factory _CursorAvailableModelsDto.fromJson(Map<String, dynamic> json) => _$CursorAvailableModelsDtoFromJson(json);

 final  List<CursorAvailableModelDto> _models;
@override@JsonKey() List<CursorAvailableModelDto> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}


/// Create a copy of CursorAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorAvailableModelsDtoCopyWith<_CursorAvailableModelsDto> get copyWith => __$CursorAvailableModelsDtoCopyWithImpl<_CursorAvailableModelsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorAvailableModelsDto&&const DeepCollectionEquality().equals(other._models, _models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_models));

@override
String toString() {
  return 'CursorAvailableModelsDto(models: $models)';
}


}

/// @nodoc
abstract mixin class _$CursorAvailableModelsDtoCopyWith<$Res> implements $CursorAvailableModelsDtoCopyWith<$Res> {
  factory _$CursorAvailableModelsDtoCopyWith(_CursorAvailableModelsDto value, $Res Function(_CursorAvailableModelsDto) _then) = __$CursorAvailableModelsDtoCopyWithImpl;
@override @useResult
$Res call({
 List<CursorAvailableModelDto> models
});




}
/// @nodoc
class __$CursorAvailableModelsDtoCopyWithImpl<$Res>
    implements _$CursorAvailableModelsDtoCopyWith<$Res> {
  __$CursorAvailableModelsDtoCopyWithImpl(this._self, this._then);

  final _CursorAvailableModelsDto _self;
  final $Res Function(_CursorAvailableModelsDto) _then;

/// Create a copy of CursorAvailableModelsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? models = null,}) {
  return _then(_CursorAvailableModelsDto(
models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<CursorAvailableModelDto>,
  ));
}


}


/// @nodoc
mixin _$CursorAvailableModelDto {

 String get value; String? get name; List<CursorModelConfigOptionDto> get configOptions;
/// Create a copy of CursorAvailableModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorAvailableModelDtoCopyWith<CursorAvailableModelDto> get copyWith => _$CursorAvailableModelDtoCopyWithImpl<CursorAvailableModelDto>(this as CursorAvailableModelDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorAvailableModelDto&&(identical(other.value, value) || other.value == value)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.configOptions, configOptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,name,const DeepCollectionEquality().hash(configOptions));

@override
String toString() {
  return 'CursorAvailableModelDto(value: $value, name: $name, configOptions: $configOptions)';
}


}

/// @nodoc
abstract mixin class $CursorAvailableModelDtoCopyWith<$Res>  {
  factory $CursorAvailableModelDtoCopyWith(CursorAvailableModelDto value, $Res Function(CursorAvailableModelDto) _then) = _$CursorAvailableModelDtoCopyWithImpl;
@useResult
$Res call({
 String value, String? name, List<CursorModelConfigOptionDto> configOptions
});




}
/// @nodoc
class _$CursorAvailableModelDtoCopyWithImpl<$Res>
    implements $CursorAvailableModelDtoCopyWith<$Res> {
  _$CursorAvailableModelDtoCopyWithImpl(this._self, this._then);

  final CursorAvailableModelDto _self;
  final $Res Function(CursorAvailableModelDto) _then;

/// Create a copy of CursorAvailableModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? name = freezed,Object? configOptions = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,configOptions: null == configOptions ? _self.configOptions : configOptions // ignore: cast_nullable_to_non_nullable
as List<CursorModelConfigOptionDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorAvailableModelDto implements CursorAvailableModelDto {
  const _CursorAvailableModelDto({required this.value, required this.name, final  List<CursorModelConfigOptionDto> configOptions = const <CursorModelConfigOptionDto>[]}): _configOptions = configOptions;
  factory _CursorAvailableModelDto.fromJson(Map<String, dynamic> json) => _$CursorAvailableModelDtoFromJson(json);

@override final  String value;
@override final  String? name;
 final  List<CursorModelConfigOptionDto> _configOptions;
@override@JsonKey() List<CursorModelConfigOptionDto> get configOptions {
  if (_configOptions is EqualUnmodifiableListView) return _configOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_configOptions);
}


/// Create a copy of CursorAvailableModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorAvailableModelDtoCopyWith<_CursorAvailableModelDto> get copyWith => __$CursorAvailableModelDtoCopyWithImpl<_CursorAvailableModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorAvailableModelDto&&(identical(other.value, value) || other.value == value)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._configOptions, _configOptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,name,const DeepCollectionEquality().hash(_configOptions));

@override
String toString() {
  return 'CursorAvailableModelDto(value: $value, name: $name, configOptions: $configOptions)';
}


}

/// @nodoc
abstract mixin class _$CursorAvailableModelDtoCopyWith<$Res> implements $CursorAvailableModelDtoCopyWith<$Res> {
  factory _$CursorAvailableModelDtoCopyWith(_CursorAvailableModelDto value, $Res Function(_CursorAvailableModelDto) _then) = __$CursorAvailableModelDtoCopyWithImpl;
@override @useResult
$Res call({
 String value, String? name, List<CursorModelConfigOptionDto> configOptions
});




}
/// @nodoc
class __$CursorAvailableModelDtoCopyWithImpl<$Res>
    implements _$CursorAvailableModelDtoCopyWith<$Res> {
  __$CursorAvailableModelDtoCopyWithImpl(this._self, this._then);

  final _CursorAvailableModelDto _self;
  final $Res Function(_CursorAvailableModelDto) _then;

/// Create a copy of CursorAvailableModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? name = freezed,Object? configOptions = null,}) {
  return _then(_CursorAvailableModelDto(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,configOptions: null == configOptions ? _self._configOptions : configOptions // ignore: cast_nullable_to_non_nullable
as List<CursorModelConfigOptionDto>,
  ));
}


}


/// @nodoc
mixin _$CursorModelConfigOptionDto {

 String get id; String? get name; String? get description; String? get category; String? get currentValue; List<CursorConfigOptionValueDto> get options;
/// Create a copy of CursorModelConfigOptionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorModelConfigOptionDtoCopyWith<CursorModelConfigOptionDto> get copyWith => _$CursorModelConfigOptionDtoCopyWithImpl<CursorModelConfigOptionDto>(this as CursorModelConfigOptionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorModelConfigOptionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.currentValue, currentValue) || other.currentValue == currentValue)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,category,currentValue,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'CursorModelConfigOptionDto(id: $id, name: $name, description: $description, category: $category, currentValue: $currentValue, options: $options)';
}


}

/// @nodoc
abstract mixin class $CursorModelConfigOptionDtoCopyWith<$Res>  {
  factory $CursorModelConfigOptionDtoCopyWith(CursorModelConfigOptionDto value, $Res Function(CursorModelConfigOptionDto) _then) = _$CursorModelConfigOptionDtoCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String? description, String? category, String? currentValue, List<CursorConfigOptionValueDto> options
});




}
/// @nodoc
class _$CursorModelConfigOptionDtoCopyWithImpl<$Res>
    implements $CursorModelConfigOptionDtoCopyWith<$Res> {
  _$CursorModelConfigOptionDtoCopyWithImpl(this._self, this._then);

  final CursorModelConfigOptionDto _self;
  final $Res Function(CursorModelConfigOptionDto) _then;

/// Create a copy of CursorModelConfigOptionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? description = freezed,Object? category = freezed,Object? currentValue = freezed,Object? options = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,currentValue: freezed == currentValue ? _self.currentValue : currentValue // ignore: cast_nullable_to_non_nullable
as String?,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<CursorConfigOptionValueDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorModelConfigOptionDto implements CursorModelConfigOptionDto {
  const _CursorModelConfigOptionDto({required this.id, required this.name, required this.description, required this.category, required this.currentValue, final  List<CursorConfigOptionValueDto> options = const <CursorConfigOptionValueDto>[]}): _options = options;
  factory _CursorModelConfigOptionDto.fromJson(Map<String, dynamic> json) => _$CursorModelConfigOptionDtoFromJson(json);

@override final  String id;
@override final  String? name;
@override final  String? description;
@override final  String? category;
@override final  String? currentValue;
 final  List<CursorConfigOptionValueDto> _options;
@override@JsonKey() List<CursorConfigOptionValueDto> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of CursorModelConfigOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorModelConfigOptionDtoCopyWith<_CursorModelConfigOptionDto> get copyWith => __$CursorModelConfigOptionDtoCopyWithImpl<_CursorModelConfigOptionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorModelConfigOptionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.currentValue, currentValue) || other.currentValue == currentValue)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,category,currentValue,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'CursorModelConfigOptionDto(id: $id, name: $name, description: $description, category: $category, currentValue: $currentValue, options: $options)';
}


}

/// @nodoc
abstract mixin class _$CursorModelConfigOptionDtoCopyWith<$Res> implements $CursorModelConfigOptionDtoCopyWith<$Res> {
  factory _$CursorModelConfigOptionDtoCopyWith(_CursorModelConfigOptionDto value, $Res Function(_CursorModelConfigOptionDto) _then) = __$CursorModelConfigOptionDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String? description, String? category, String? currentValue, List<CursorConfigOptionValueDto> options
});




}
/// @nodoc
class __$CursorModelConfigOptionDtoCopyWithImpl<$Res>
    implements _$CursorModelConfigOptionDtoCopyWith<$Res> {
  __$CursorModelConfigOptionDtoCopyWithImpl(this._self, this._then);

  final _CursorModelConfigOptionDto _self;
  final $Res Function(_CursorModelConfigOptionDto) _then;

/// Create a copy of CursorModelConfigOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? description = freezed,Object? category = freezed,Object? currentValue = freezed,Object? options = null,}) {
  return _then(_CursorModelConfigOptionDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,currentValue: freezed == currentValue ? _self.currentValue : currentValue // ignore: cast_nullable_to_non_nullable
as String?,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<CursorConfigOptionValueDto>,
  ));
}


}


/// @nodoc
mixin _$CursorConfigOptionValueDto {

 String get value; String? get name; String? get description;
/// Create a copy of CursorConfigOptionValueDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorConfigOptionValueDtoCopyWith<CursorConfigOptionValueDto> get copyWith => _$CursorConfigOptionValueDtoCopyWithImpl<CursorConfigOptionValueDto>(this as CursorConfigOptionValueDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorConfigOptionValueDto&&(identical(other.value, value) || other.value == value)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,name,description);

@override
String toString() {
  return 'CursorConfigOptionValueDto(value: $value, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class $CursorConfigOptionValueDtoCopyWith<$Res>  {
  factory $CursorConfigOptionValueDtoCopyWith(CursorConfigOptionValueDto value, $Res Function(CursorConfigOptionValueDto) _then) = _$CursorConfigOptionValueDtoCopyWithImpl;
@useResult
$Res call({
 String value, String? name, String? description
});




}
/// @nodoc
class _$CursorConfigOptionValueDtoCopyWithImpl<$Res>
    implements $CursorConfigOptionValueDtoCopyWith<$Res> {
  _$CursorConfigOptionValueDtoCopyWithImpl(this._self, this._then);

  final CursorConfigOptionValueDto _self;
  final $Res Function(CursorConfigOptionValueDto) _then;

/// Create a copy of CursorConfigOptionValueDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? name = freezed,Object? description = freezed,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CursorConfigOptionValueDto implements CursorConfigOptionValueDto {
  const _CursorConfigOptionValueDto({required this.value, required this.name, required this.description});
  factory _CursorConfigOptionValueDto.fromJson(Map<String, dynamic> json) => _$CursorConfigOptionValueDtoFromJson(json);

@override final  String value;
@override final  String? name;
@override final  String? description;

/// Create a copy of CursorConfigOptionValueDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CursorConfigOptionValueDtoCopyWith<_CursorConfigOptionValueDto> get copyWith => __$CursorConfigOptionValueDtoCopyWithImpl<_CursorConfigOptionValueDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CursorConfigOptionValueDto&&(identical(other.value, value) || other.value == value)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,name,description);

@override
String toString() {
  return 'CursorConfigOptionValueDto(value: $value, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CursorConfigOptionValueDtoCopyWith<$Res> implements $CursorConfigOptionValueDtoCopyWith<$Res> {
  factory _$CursorConfigOptionValueDtoCopyWith(_CursorConfigOptionValueDto value, $Res Function(_CursorConfigOptionValueDto) _then) = __$CursorConfigOptionValueDtoCopyWithImpl;
@override @useResult
$Res call({
 String value, String? name, String? description
});




}
/// @nodoc
class __$CursorConfigOptionValueDtoCopyWithImpl<$Res>
    implements _$CursorConfigOptionValueDtoCopyWith<$Res> {
  __$CursorConfigOptionValueDtoCopyWithImpl(this._self, this._then);

  final _CursorConfigOptionValueDto _self;
  final $Res Function(_CursorConfigOptionValueDto) _then;

/// Create a copy of CursorConfigOptionValueDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? name = freezed,Object? description = freezed,}) {
  return _then(_CursorConfigOptionValueDto(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
