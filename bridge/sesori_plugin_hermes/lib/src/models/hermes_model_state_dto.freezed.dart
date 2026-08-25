// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hermes_model_state_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HermesModelInfoDto {

 String? get modelId; String? get name; String? get description;
/// Create a copy of HermesModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesModelInfoDtoCopyWith<HermesModelInfoDto> get copyWith => _$HermesModelInfoDtoCopyWithImpl<HermesModelInfoDto>(this as HermesModelInfoDto, _$identity);

  /// Serializes this HermesModelInfoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesModelInfoDto&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,name,description);

@override
String toString() {
  return 'HermesModelInfoDto(modelId: $modelId, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class $HermesModelInfoDtoCopyWith<$Res>  {
  factory $HermesModelInfoDtoCopyWith(HermesModelInfoDto value, $Res Function(HermesModelInfoDto) _then) = _$HermesModelInfoDtoCopyWithImpl;
@useResult
$Res call({
 String? modelId, String? name, String? description
});




}
/// @nodoc
class _$HermesModelInfoDtoCopyWithImpl<$Res>
    implements $HermesModelInfoDtoCopyWith<$Res> {
  _$HermesModelInfoDtoCopyWithImpl(this._self, this._then);

  final HermesModelInfoDto _self;
  final $Res Function(HermesModelInfoDto) _then;

/// Create a copy of HermesModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? modelId = freezed,Object? name = freezed,Object? description = freezed,}) {
  return _then(HermesModelInfoDto(
modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HermesModelInfoDto implements HermesModelInfoDto {
  const _HermesModelInfoDto({required this.modelId, required this.name, required this.description});
  factory _HermesModelInfoDto.fromJson(Map<String, dynamic> json) => _$HermesModelInfoDtoFromJson(json);

@override final  String? modelId;
@override final  String? name;
@override final  String? description;

/// Create a copy of HermesModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesModelInfoDtoCopyWith<_HermesModelInfoDto> get copyWith => __$HermesModelInfoDtoCopyWithImpl<_HermesModelInfoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesModelInfoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesModelInfoDto&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,name,description);

@override
String toString() {
  return 'HermesModelInfoDto(modelId: $modelId, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class _$HermesModelInfoDtoCopyWith<$Res> implements $HermesModelInfoDtoCopyWith<$Res> {
  factory _$HermesModelInfoDtoCopyWith(_HermesModelInfoDto value, $Res Function(_HermesModelInfoDto) _then) = __$HermesModelInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 String? modelId, String? name, String? description
});




}
/// @nodoc
class __$HermesModelInfoDtoCopyWithImpl<$Res>
    implements _$HermesModelInfoDtoCopyWith<$Res> {
  __$HermesModelInfoDtoCopyWithImpl(this._self, this._then);

  final _HermesModelInfoDto _self;
  final $Res Function(_HermesModelInfoDto) _then;

/// Create a copy of HermesModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? modelId = freezed,Object? name = freezed,Object? description = freezed,}) {
  return _then(_HermesModelInfoDto(
modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$HermesSessionModelStateDto {

 List<HermesModelInfoDto> get availableModels; String? get currentModelId;
/// Create a copy of HermesSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesSessionModelStateDtoCopyWith<HermesSessionModelStateDto> get copyWith => _$HermesSessionModelStateDtoCopyWithImpl<HermesSessionModelStateDto>(this as HermesSessionModelStateDto, _$identity);

  /// Serializes this HermesSessionModelStateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesSessionModelStateDto&&const DeepCollectionEquality().equals(other.availableModels, availableModels)&&(identical(other.currentModelId, currentModelId) || other.currentModelId == currentModelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availableModels),currentModelId);

@override
String toString() {
  return 'HermesSessionModelStateDto(availableModels: $availableModels, currentModelId: $currentModelId)';
}


}

/// @nodoc
abstract mixin class $HermesSessionModelStateDtoCopyWith<$Res>  {
  factory $HermesSessionModelStateDtoCopyWith(HermesSessionModelStateDto value, $Res Function(HermesSessionModelStateDto) _then) = _$HermesSessionModelStateDtoCopyWithImpl;
@useResult
$Res call({
 List<HermesModelInfoDto> availableModels, String? currentModelId
});




}
/// @nodoc
class _$HermesSessionModelStateDtoCopyWithImpl<$Res>
    implements $HermesSessionModelStateDtoCopyWith<$Res> {
  _$HermesSessionModelStateDtoCopyWithImpl(this._self, this._then);

  final HermesSessionModelStateDto _self;
  final $Res Function(HermesSessionModelStateDto) _then;

/// Create a copy of HermesSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availableModels = null,Object? currentModelId = freezed,}) {
  return _then(HermesSessionModelStateDto(
availableModels: null == availableModels ? _self.availableModels : availableModels // ignore: cast_nullable_to_non_nullable
as List<HermesModelInfoDto>,currentModelId: freezed == currentModelId ? _self.currentModelId : currentModelId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HermesSessionModelStateDto implements HermesSessionModelStateDto {
  const _HermesSessionModelStateDto({ List<HermesModelInfoDto> availableModels = const <HermesModelInfoDto>[], required this.currentModelId}): _availableModels = availableModels;
  factory _HermesSessionModelStateDto.fromJson(Map<String, dynamic> json) => _$HermesSessionModelStateDtoFromJson(json);

 final  List<HermesModelInfoDto> _availableModels;
@override@JsonKey() List<HermesModelInfoDto> get availableModels {
  if (_availableModels is EqualUnmodifiableListView) return _availableModels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableModels);
}

@override final  String? currentModelId;

/// Create a copy of HermesSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesSessionModelStateDtoCopyWith<_HermesSessionModelStateDto> get copyWith => __$HermesSessionModelStateDtoCopyWithImpl<_HermesSessionModelStateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesSessionModelStateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesSessionModelStateDto&&const DeepCollectionEquality().equals(other._availableModels, _availableModels)&&(identical(other.currentModelId, currentModelId) || other.currentModelId == currentModelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availableModels),currentModelId);

@override
String toString() {
  return 'HermesSessionModelStateDto(availableModels: $availableModels, currentModelId: $currentModelId)';
}


}

/// @nodoc
abstract mixin class _$HermesSessionModelStateDtoCopyWith<$Res> implements $HermesSessionModelStateDtoCopyWith<$Res> {
  factory _$HermesSessionModelStateDtoCopyWith(_HermesSessionModelStateDto value, $Res Function(_HermesSessionModelStateDto) _then) = __$HermesSessionModelStateDtoCopyWithImpl;
@override @useResult
$Res call({
 List<HermesModelInfoDto> availableModels, String? currentModelId
});




}
/// @nodoc
class __$HermesSessionModelStateDtoCopyWithImpl<$Res>
    implements _$HermesSessionModelStateDtoCopyWith<$Res> {
  __$HermesSessionModelStateDtoCopyWithImpl(this._self, this._then);

  final _HermesSessionModelStateDto _self;
  final $Res Function(_HermesSessionModelStateDto) _then;

/// Create a copy of HermesSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availableModels = null,Object? currentModelId = freezed,}) {
  return _then(_HermesSessionModelStateDto(
availableModels: null == availableModels ? _self._availableModels : availableModels // ignore: cast_nullable_to_non_nullable
as List<HermesModelInfoDto>,currentModelId: freezed == currentModelId ? _self.currentModelId : currentModelId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
