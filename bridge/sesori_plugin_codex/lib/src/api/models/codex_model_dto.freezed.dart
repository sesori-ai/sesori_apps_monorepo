// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_model_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelListResponseDto&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),nextCursor);

@override
String toString() {
  return 'CodexModelListResponseDto(data: $data, nextCursor: $nextCursor)';
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
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CodexModelDto>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexModelListResponseDto implements CodexModelListResponseDto {
  const _CodexModelListResponseDto({@CodexModelListConverter() required final  List<CodexModelDto> data, required this.nextCursor}): _data = data;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelListResponseDto&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),nextCursor);

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

 String? get id; String? get displayName; bool? get hidden;@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? get supportedReasoningEfforts; String? get defaultReasoningEffort; bool? get isDefault;
/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelDtoCopyWith<CodexModelDto> get copyWith => _$CodexModelDtoCopyWithImpl<CodexModelDto>(this as CodexModelDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&const DeepCollectionEquality().equals(other.supportedReasoningEfforts, supportedReasoningEfforts)&&(identical(other.defaultReasoningEffort, defaultReasoningEffort) || other.defaultReasoningEffort == defaultReasoningEffort)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,hidden,const DeepCollectionEquality().hash(supportedReasoningEfforts),defaultReasoningEffort,isDefault);

@override
String toString() {
  return 'CodexModelDto(id: $id, displayName: $displayName, hidden: $hidden, supportedReasoningEfforts: $supportedReasoningEfforts, defaultReasoningEffort: $defaultReasoningEffort, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $CodexModelDtoCopyWith<$Res>  {
  factory $CodexModelDtoCopyWith(CodexModelDto value, $Res Function(CodexModelDto) _then) = _$CodexModelDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? displayName, bool? hidden,@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, String? defaultReasoningEffort, bool? isDefault
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? supportedReasoningEfforts = freezed,Object? defaultReasoningEffort = freezed,Object? isDefault = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,supportedReasoningEfforts: freezed == supportedReasoningEfforts ? _self.supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortOptionDto>?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexModelDto implements CodexModelDto {
  const _CodexModelDto({required this.id, required this.displayName, required this.hidden, @CodexReasoningEffortListConverter() required final  List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, required this.defaultReasoningEffort, required this.isDefault}): _supportedReasoningEfforts = supportedReasoningEfforts;
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

/// Create a copy of CodexModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexModelDtoCopyWith<_CodexModelDto> get copyWith => __$CodexModelDtoCopyWithImpl<_CodexModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexModelDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&const DeepCollectionEquality().equals(other._supportedReasoningEfforts, _supportedReasoningEfforts)&&(identical(other.defaultReasoningEffort, defaultReasoningEffort) || other.defaultReasoningEffort == defaultReasoningEffort)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,hidden,const DeepCollectionEquality().hash(_supportedReasoningEfforts),defaultReasoningEffort,isDefault);

@override
String toString() {
  return 'CodexModelDto(id: $id, displayName: $displayName, hidden: $hidden, supportedReasoningEfforts: $supportedReasoningEfforts, defaultReasoningEffort: $defaultReasoningEffort, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$CodexModelDtoCopyWith<$Res> implements $CodexModelDtoCopyWith<$Res> {
  factory _$CodexModelDtoCopyWith(_CodexModelDto value, $Res Function(_CodexModelDto) _then) = __$CodexModelDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? displayName, bool? hidden,@CodexReasoningEffortListConverter() List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts, String? defaultReasoningEffort, bool? isDefault
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? displayName = freezed,Object? hidden = freezed,Object? supportedReasoningEfforts = freezed,Object? defaultReasoningEffort = freezed,Object? isDefault = freezed,}) {
  return _then(_CodexModelDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,hidden: freezed == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool?,supportedReasoningEfforts: freezed == supportedReasoningEfforts ? _self._supportedReasoningEfforts : supportedReasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<CodexReasoningEffortOptionDto>?,defaultReasoningEffort: freezed == defaultReasoningEffort ? _self.defaultReasoningEffort : defaultReasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexReasoningEffortOptionDto&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,reasoningEffort,description);

@override
String toString() {
  return 'CodexReasoningEffortOptionDto(reasoningEffort: $reasoningEffort, description: $description)';
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
  return _then(_self.copyWith(
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
int get hashCode => Object.hash(runtimeType,reasoningEffort,description);

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

// dart format on
