// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_model_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexModelListResponseDto {

@CodexModelListConverter() List<CodexModelDto> get data; String? get nextCursor;
/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelListResponseDtoCopyWith<CodexModelListResponseDto> get copyWith => _$CodexModelListResponseDtoCopyWithImpl<CodexModelListResponseDto>(this as CodexModelListResponseDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexModelListResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelListResponseDto&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexModelListResponseDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.nextCursor);
}

@override
String toString() {
  final _this = this as CodexModelListResponseDto;
  return 'CodexModelListResponseDto(data: ${_this.data}, nextCursor: ${_this.nextCursor})';
}


}

/// @nodoc
abstract mixin class $CodexModelListResponseDtoCopyWith<$Res>  {
  factory $CodexModelListResponseDtoCopyWith(CodexModelListResponseDto value, $Res Function(CodexModelListResponseDto) _then) = _$CodexModelListResponseDtoCopyWithImpl;
@useResult
$Res call({
@CodexModelListConverter() List<CodexModelDto> data, String? nextCursor
});




}
/// @nodoc
class _$CodexModelListResponseDtoCopyWithImpl<$Res>
    implements $CodexModelListResponseDtoCopyWith<$Res> {
  _$CodexModelListResponseDtoCopyWithImpl(this._self, this._then);

  final CodexModelListResponseDto _self;
  final $Res Function(CodexModelListResponseDto) _then;

/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? nextCursor = freezed,}) {
  return _then(CodexModelListResponseDto(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CodexModelDto>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexModelListResponseDto implements CodexModelListResponseDto {
  const _CodexModelListResponseDto({@CodexModelListConverter() required  List<CodexModelDto> data, required this.nextCursor}): _data = data;
  factory _CodexModelListResponseDto.fromJson(Map<String, dynamic> json) => _$CodexModelListResponseDtoFromJson(json);

 final  List<CodexModelDto> _data;
@override@CodexModelListConverter() List<CodexModelDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  String? nextCursor;

/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelListResponseDtoCopyWith<_CodexModelListResponseDto> get copyWith => __$CodexModelListResponseDtoCopyWithImpl<_CodexModelListResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelListResponseDto&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),nextCursor);
}

@override
String toString() {
    return 'CodexModelListResponseDto(data: $data, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$CodexModelListResponseDtoCopyWith<$Res> implements $CodexModelListResponseDtoCopyWith<$Res> {
  factory _$CodexModelListResponseDtoCopyWith(_CodexModelListResponseDto value, $Res Function(_CodexModelListResponseDto) _then) = __$CodexModelListResponseDtoCopyWithImpl;
@override @useResult
$Res call({
@CodexModelListConverter() List<CodexModelDto> data, String? nextCursor
});




}
/// @nodoc
class __$CodexModelListResponseDtoCopyWithImpl<$Res>
    implements _$CodexModelListResponseDtoCopyWith<$Res> {
  __$CodexModelListResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexModelListResponseDto _self;
  final $Res Function(_CodexModelListResponseDto) _then;

/// Create a copy of CodexModelListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? nextCursor = freezed,}) {
  return _then(_CodexModelListResponseDto(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CodexModelDto>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexModelDto {

 String? get id; String? get displayName; bool? get hidden;@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? get supportedReasoningEfforts; String? get defaultReasoningEffort; bool? get isDefault; List<CodexModelServiceTierDto>? get serviceTiers;
/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelDtoCopyWith<CodexModelDto> get copyWith => _$CodexModelDtoCopyWithImpl<CodexModelDto>(this as CodexModelDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexModelDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden)&&const DeepCollectionEquality().equals(other.supportedReasoningEfforts, _this.supportedReasoningEfforts)&&(identical(other.defaultReasoningEffort, _this.defaultReasoningEffort) || other.defaultReasoningEffort == _this.defaultReasoningEffort)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&const DeepCollectionEquality().equals(other.serviceTiers, _this.serviceTiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexModelDto;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.hidden,const DeepCollectionEquality().hash(_this.supportedReasoningEfforts),_this.defaultReasoningEffort,_this.isDefault,const DeepCollectionEquality().hash(_this.serviceTiers));
}

@override
String toString() {
  final _this = this as CodexModelDto;
  return 'CodexModelDto(id: ${_this.id}, displayName: ${_this.displayName}, hidden: ${_this.hidden}, supportedReasoningEfforts: ${_this.supportedReasoningEfforts}, defaultReasoningEffort: ${_this.defaultReasoningEffort}, isDefault: ${_this.isDefault}, serviceTiers: ${_this.serviceTiers})';
}


}

/// @nodoc
abstract mixin class $CodexModelDtoCopyWith<$Res>  {
  factory $CodexModelDtoCopyWith(CodexModelDto value, $Res Function(CodexModelDto) _then) = _$CodexModelDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? displayName, bool? hidden,@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, String? defaultReasoningEffort, bool? isDefault, List<CodexModelServiceTierDto>? serviceTiers
});




}
/// @nodoc
class _$CodexModelDtoCopyWithImpl<$Res>
    implements $CodexModelDtoCopyWith<$Res> {
  _$CodexModelDtoCopyWithImpl(this._self, this._then);

  final CodexModelDto _self;
  final $Res Function(CodexModelDto) _then;

/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? supportedReasoningEfforts = freezed,Object? defaultReasoningEffort = freezed,Object? isDefault = freezed,Object? serviceTiers = freezed,}) {
  return _then(CodexModelDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,supportedReasoningEfforts: freezed == supportedReasoningEfforts ? _self.supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortOptionDto>?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,serviceTiers: freezed == serviceTiers ? _self.serviceTiers : serviceTiers // ignore: cast_nullable_to_non_nullable
as List<CodexModelServiceTierDto>?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexModelDto implements CodexModelDto {
  const _CodexModelDto({required this.id, required this.displayName, required this.hidden, @CodexReasoningEffortListConverter() required  List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, required this.defaultReasoningEffort, required this.isDefault, required  List<CodexModelServiceTierDto>? serviceTiers}): _supportedReasoningEfforts = supportedReasoningEfforts,_serviceTiers = serviceTiers;
  factory _CodexModelDto.fromJson(Map<String, dynamic> json) => _$CodexModelDtoFromJson(json);

@override final  String? id;
@override final  String? displayName;
@override final  bool? hidden;
 final  List<CodexReasoningEffortOptionDto>? _supportedReasoningEfforts;
@override@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? get supportedReasoningEfforts {
  final value = _supportedReasoningEfforts;
  if (value == null) return null;
  if (_supportedReasoningEfforts is EqualUnmodifiableListView) return _supportedReasoningEfforts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? defaultReasoningEffort;
@override final  bool? isDefault;
 final  List<CodexModelServiceTierDto>? _serviceTiers;
@override List<CodexModelServiceTierDto>? get serviceTiers {
  final value = _serviceTiers;
  if (value == null) return null;
  if (_serviceTiers is EqualUnmodifiableListView) return _serviceTiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelDtoCopyWith<_CodexModelDto> get copyWith => __$CodexModelDtoCopyWithImpl<_CodexModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&const DeepCollectionEquality().equals(other.supportedReasoningEfforts, _supportedReasoningEfforts)&&(identical(other.defaultReasoningEffort, defaultReasoningEffort) || other.defaultReasoningEffort == defaultReasoningEffort)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&const DeepCollectionEquality().equals(other.serviceTiers, _serviceTiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,hidden,const DeepCollectionEquality().hash(_supportedReasoningEfforts),defaultReasoningEffort,isDefault,const DeepCollectionEquality().hash(_serviceTiers));
}

@override
String toString() {
    return 'CodexModelDto(id: $id, displayName: $displayName, hidden: $hidden, supportedReasoningEfforts: $supportedReasoningEfforts, defaultReasoningEffort: $defaultReasoningEffort, isDefault: $isDefault, serviceTiers: $serviceTiers)';
}


}

/// @nodoc
abstract mixin class _$CodexModelDtoCopyWith<$Res> implements $CodexModelDtoCopyWith<$Res> {
  factory _$CodexModelDtoCopyWith(_CodexModelDto value, $Res Function(_CodexModelDto) _then) = __$CodexModelDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? displayName, bool? hidden,@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, String? defaultReasoningEffort, bool? isDefault, List<CodexModelServiceTierDto>? serviceTiers
});




}
/// @nodoc
class __$CodexModelDtoCopyWithImpl<$Res>
    implements _$CodexModelDtoCopyWith<$Res> {
  __$CodexModelDtoCopyWithImpl(this._self, this._then);

  final _CodexModelDto _self;
  final $Res Function(_CodexModelDto) _then;

/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? supportedReasoningEfforts = freezed,Object? defaultReasoningEffort = freezed,Object? isDefault = freezed,Object? serviceTiers = freezed,}) {
  return _then(_CodexModelDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,supportedReasoningEfforts: freezed == supportedReasoningEfforts ? _self._supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortOptionDto>?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,serviceTiers: freezed == serviceTiers ? _self._serviceTiers : serviceTiers // ignore: cast_nullable_to_non_nullable
as List<CodexModelServiceTierDto>?,
  ));
}


}


/// @nodoc
mixin _$CodexReasoningEffortOptionDto {

 String? get reasoningEffort; String? get description;
/// Create a copy of CodexReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexReasoningEffortOptionDtoCopyWith<CodexReasoningEffortOptionDto> get copyWith => _$CodexReasoningEffortOptionDtoCopyWithImpl<CodexReasoningEffortOptionDto>(this as CodexReasoningEffortOptionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexReasoningEffortOptionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexReasoningEffortOptionDto&&(identical(other.reasoningEffort, _this.reasoningEffort) || other.reasoningEffort == _this.reasoningEffort)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexReasoningEffortOptionDto;
  return Object.hash(runtimeType,_this.reasoningEffort,_this.description);
}

@override
String toString() {
  final _this = this as CodexReasoningEffortOptionDto;
  return 'CodexReasoningEffortOptionDto(reasoningEffort: ${_this.reasoningEffort}, description: ${_this.description})';
}


}

/// @nodoc
abstract mixin class $CodexReasoningEffortOptionDtoCopyWith<$Res>  {
  factory $CodexReasoningEffortOptionDtoCopyWith(CodexReasoningEffortOptionDto value, $Res Function(CodexReasoningEffortOptionDto) _then) = _$CodexReasoningEffortOptionDtoCopyWithImpl;
@useResult
$Res call({
 String? reasoningEffort, String? description
});




}
/// @nodoc
class _$CodexReasoningEffortOptionDtoCopyWithImpl<$Res>
    implements $CodexReasoningEffortOptionDtoCopyWith<$Res> {
  _$CodexReasoningEffortOptionDtoCopyWithImpl(this._self, this._then);

  final CodexReasoningEffortOptionDto _self;
  final $Res Function(CodexReasoningEffortOptionDto) _then;

/// Create a copy of CodexReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reasoningEffort = freezed,Object? description = freezed,}) {
  return _then(CodexReasoningEffortOptionDto(
reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexReasoningEffortOptionDto implements CodexReasoningEffortOptionDto {
  const _CodexReasoningEffortOptionDto({required this.reasoningEffort, required this.description});
  factory _CodexReasoningEffortOptionDto.fromJson(Map<String, dynamic> json) => _$CodexReasoningEffortOptionDtoFromJson(json);

@override final  String? reasoningEffort;
@override final  String? description;

/// Create a copy of CodexReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexReasoningEffortOptionDtoCopyWith<_CodexReasoningEffortOptionDto> get copyWith => __$CodexReasoningEffortOptionDtoCopyWithImpl<_CodexReasoningEffortOptionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexReasoningEffortOptionDto&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reasoningEffort,description);
}

@override
String toString() {
    return 'CodexReasoningEffortOptionDto(reasoningEffort: $reasoningEffort, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CodexReasoningEffortOptionDtoCopyWith<$Res> implements $CodexReasoningEffortOptionDtoCopyWith<$Res> {
  factory _$CodexReasoningEffortOptionDtoCopyWith(_CodexReasoningEffortOptionDto value, $Res Function(_CodexReasoningEffortOptionDto) _then) = __$CodexReasoningEffortOptionDtoCopyWithImpl;
@override @useResult
$Res call({
 String? reasoningEffort, String? description
});




}
/// @nodoc
class __$CodexReasoningEffortOptionDtoCopyWithImpl<$Res>
    implements _$CodexReasoningEffortOptionDtoCopyWith<$Res> {
  __$CodexReasoningEffortOptionDtoCopyWithImpl(this._self, this._then);

  final _CodexReasoningEffortOptionDto _self;
  final $Res Function(_CodexReasoningEffortOptionDto) _then;

/// Create a copy of CodexReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reasoningEffort = freezed,Object? description = freezed,}) {
  return _then(_CodexReasoningEffortOptionDto(
reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexModelServiceTierDto {

 String? get id; String? get name; String? get description;
/// Create a copy of CodexModelServiceTierDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelServiceTierDtoCopyWith<CodexModelServiceTierDto> get copyWith => _$CodexModelServiceTierDtoCopyWithImpl<CodexModelServiceTierDto>(this as CodexModelServiceTierDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexModelServiceTierDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelServiceTierDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexModelServiceTierDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.description);
}

@override
String toString() {
  final _this = this as CodexModelServiceTierDto;
  return 'CodexModelServiceTierDto(id: ${_this.id}, name: ${_this.name}, description: ${_this.description})';
}


}

/// @nodoc
abstract mixin class $CodexModelServiceTierDtoCopyWith<$Res>  {
  factory $CodexModelServiceTierDtoCopyWith(CodexModelServiceTierDto value, $Res Function(CodexModelServiceTierDto) _then) = _$CodexModelServiceTierDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? name, String? description
});




}
/// @nodoc
class _$CodexModelServiceTierDtoCopyWithImpl<$Res>
    implements $CodexModelServiceTierDtoCopyWith<$Res> {
  _$CodexModelServiceTierDtoCopyWithImpl(this._self, this._then);

  final CodexModelServiceTierDto _self;
  final $Res Function(CodexModelServiceTierDto) _then;

/// Create a copy of CodexModelServiceTierDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = freezed,Object? description = freezed,}) {
  return _then(CodexModelServiceTierDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexModelServiceTierDto implements CodexModelServiceTierDto {
  const _CodexModelServiceTierDto({required this.id, required this.name, required this.description});
  factory _CodexModelServiceTierDto.fromJson(Map<String, dynamic> json) => _$CodexModelServiceTierDtoFromJson(json);

@override final  String? id;
@override final  String? name;
@override final  String? description;

/// Create a copy of CodexModelServiceTierDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelServiceTierDtoCopyWith<_CodexModelServiceTierDto> get copyWith => __$CodexModelServiceTierDtoCopyWithImpl<_CodexModelServiceTierDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelServiceTierDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,description);
}

@override
String toString() {
    return 'CodexModelServiceTierDto(id: $id, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CodexModelServiceTierDtoCopyWith<$Res> implements $CodexModelServiceTierDtoCopyWith<$Res> {
  factory _$CodexModelServiceTierDtoCopyWith(_CodexModelServiceTierDto value, $Res Function(_CodexModelServiceTierDto) _then) = __$CodexModelServiceTierDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? name, String? description
});




}
/// @nodoc
class __$CodexModelServiceTierDtoCopyWithImpl<$Res>
    implements _$CodexModelServiceTierDtoCopyWith<$Res> {
  __$CodexModelServiceTierDtoCopyWithImpl(this._self, this._then);

  final _CodexModelServiceTierDto _self;
  final $Res Function(_CodexModelServiceTierDto) _then;

/// Create a copy of CodexModelServiceTierDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? description = freezed,}) {
  return _then(_CodexModelServiceTierDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
