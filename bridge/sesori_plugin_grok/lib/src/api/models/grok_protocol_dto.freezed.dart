// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grok_protocol_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GrokReasoningEffortOptionDto {

 String? get id; String? get value; String? get label; String? get description;@JsonKey(name: "default") bool get isDefault;
/// Create a copy of GrokReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokReasoningEffortOptionDtoCopyWith<GrokReasoningEffortOptionDto> get copyWith => _$GrokReasoningEffortOptionDtoCopyWithImpl<GrokReasoningEffortOptionDto>(this as GrokReasoningEffortOptionDto, _$identity);

  /// Serializes this GrokReasoningEffortOptionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokReasoningEffortOptionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value,label,description,isDefault);

@override
String toString() {
  return 'GrokReasoningEffortOptionDto(id: $id, value: $value, label: $label, description: $description, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $GrokReasoningEffortOptionDtoCopyWith<$Res>  {
  factory $GrokReasoningEffortOptionDtoCopyWith(GrokReasoningEffortOptionDto value, $Res Function(GrokReasoningEffortOptionDto) _then) = _$GrokReasoningEffortOptionDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? value, String? label, String? description,@JsonKey(name: "default") bool isDefault
});




}
/// @nodoc
class _$GrokReasoningEffortOptionDtoCopyWithImpl<$Res>
    implements $GrokReasoningEffortOptionDtoCopyWith<$Res> {
  _$GrokReasoningEffortOptionDtoCopyWithImpl(this._self, this._then);

  final GrokReasoningEffortOptionDto _self;
  final $Res Function(GrokReasoningEffortOptionDto) _then;

/// Create a copy of GrokReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? value = freezed,Object? label = freezed,Object? description = freezed,Object? isDefault = null,}) {
  return _then(GrokReasoningEffortOptionDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _GrokReasoningEffortOptionDto implements GrokReasoningEffortOptionDto {
  const _GrokReasoningEffortOptionDto({required this.id, required this.value, required this.label, required this.description, @JsonKey(name: "default") this.isDefault = false});
  factory _GrokReasoningEffortOptionDto.fromJson(Map<String, dynamic> json) => _$GrokReasoningEffortOptionDtoFromJson(json);

@override final  String? id;
@override final  String? value;
@override final  String? label;
@override final  String? description;
@override@JsonKey(name: "default") final  bool isDefault;

/// Create a copy of GrokReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokReasoningEffortOptionDtoCopyWith<_GrokReasoningEffortOptionDto> get copyWith => __$GrokReasoningEffortOptionDtoCopyWithImpl<_GrokReasoningEffortOptionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GrokReasoningEffortOptionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokReasoningEffortOptionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value,label,description,isDefault);

@override
String toString() {
  return 'GrokReasoningEffortOptionDto(id: $id, value: $value, label: $label, description: $description, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$GrokReasoningEffortOptionDtoCopyWith<$Res> implements $GrokReasoningEffortOptionDtoCopyWith<$Res> {
  factory _$GrokReasoningEffortOptionDtoCopyWith(_GrokReasoningEffortOptionDto value, $Res Function(_GrokReasoningEffortOptionDto) _then) = __$GrokReasoningEffortOptionDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? value, String? label, String? description,@JsonKey(name: "default") bool isDefault
});




}
/// @nodoc
class __$GrokReasoningEffortOptionDtoCopyWithImpl<$Res>
    implements _$GrokReasoningEffortOptionDtoCopyWith<$Res> {
  __$GrokReasoningEffortOptionDtoCopyWithImpl(this._self, this._then);

  final _GrokReasoningEffortOptionDto _self;
  final $Res Function(_GrokReasoningEffortOptionDto) _then;

/// Create a copy of GrokReasoningEffortOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? value = freezed,Object? label = freezed,Object? description = freezed,Object? isDefault = null,}) {
  return _then(_GrokReasoningEffortOptionDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GrokModelMetadataDto {

 bool? get supportsReasoningEffort; List<GrokReasoningEffortOptionDto> get reasoningEfforts; String? get reasoningEffort;
/// Create a copy of GrokModelMetadataDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokModelMetadataDtoCopyWith<GrokModelMetadataDto> get copyWith => _$GrokModelMetadataDtoCopyWithImpl<GrokModelMetadataDto>(this as GrokModelMetadataDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokModelMetadataDto&&(identical(other.supportsReasoningEffort, supportsReasoningEffort) || other.supportsReasoningEffort == supportsReasoningEffort)&&const DeepCollectionEquality().equals(other.reasoningEfforts, reasoningEfforts)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supportsReasoningEffort,const DeepCollectionEquality().hash(reasoningEfforts),reasoningEffort);

@override
String toString() {
  return 'GrokModelMetadataDto(supportsReasoningEffort: $supportsReasoningEffort, reasoningEfforts: $reasoningEfforts, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class $GrokModelMetadataDtoCopyWith<$Res>  {
  factory $GrokModelMetadataDtoCopyWith(GrokModelMetadataDto value, $Res Function(GrokModelMetadataDto) _then) = _$GrokModelMetadataDtoCopyWithImpl;
@useResult
$Res call({
 bool? supportsReasoningEffort, List<GrokReasoningEffortOptionDto> reasoningEfforts, String? reasoningEffort
});




}
/// @nodoc
class _$GrokModelMetadataDtoCopyWithImpl<$Res>
    implements $GrokModelMetadataDtoCopyWith<$Res> {
  _$GrokModelMetadataDtoCopyWithImpl(this._self, this._then);

  final GrokModelMetadataDto _self;
  final $Res Function(GrokModelMetadataDto) _then;

/// Create a copy of GrokModelMetadataDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supportsReasoningEffort = freezed,Object? reasoningEfforts = null,Object? reasoningEffort = freezed,}) {
  return _then(GrokModelMetadataDto(
supportsReasoningEffort: freezed == supportsReasoningEffort ? _self.supportsReasoningEffort : supportsReasoningEffort // ignore: cast_nullable_to_non_nullable
as bool?,reasoningEfforts: null == reasoningEfforts ? _self.reasoningEfforts : reasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<GrokReasoningEffortOptionDto>,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokModelMetadataDto implements GrokModelMetadataDto {
  const _GrokModelMetadataDto({required this.supportsReasoningEffort,  List<GrokReasoningEffortOptionDto> reasoningEfforts = const <GrokReasoningEffortOptionDto>[], required this.reasoningEffort}): _reasoningEfforts = reasoningEfforts;
  factory _GrokModelMetadataDto.fromJson(Map<String, dynamic> json) => _$GrokModelMetadataDtoFromJson(json);

@override final  bool? supportsReasoningEffort;
 final  List<GrokReasoningEffortOptionDto> _reasoningEfforts;
@override@JsonKey() List<GrokReasoningEffortOptionDto> get reasoningEfforts {
  if (_reasoningEfforts is EqualUnmodifiableListView) return _reasoningEfforts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasoningEfforts);
}

@override final  String? reasoningEffort;

/// Create a copy of GrokModelMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokModelMetadataDtoCopyWith<_GrokModelMetadataDto> get copyWith => __$GrokModelMetadataDtoCopyWithImpl<_GrokModelMetadataDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokModelMetadataDto&&(identical(other.supportsReasoningEffort, supportsReasoningEffort) || other.supportsReasoningEffort == supportsReasoningEffort)&&const DeepCollectionEquality().equals(other._reasoningEfforts, _reasoningEfforts)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supportsReasoningEffort,const DeepCollectionEquality().hash(_reasoningEfforts),reasoningEffort);

@override
String toString() {
  return 'GrokModelMetadataDto(supportsReasoningEffort: $supportsReasoningEffort, reasoningEfforts: $reasoningEfforts, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class _$GrokModelMetadataDtoCopyWith<$Res> implements $GrokModelMetadataDtoCopyWith<$Res> {
  factory _$GrokModelMetadataDtoCopyWith(_GrokModelMetadataDto value, $Res Function(_GrokModelMetadataDto) _then) = __$GrokModelMetadataDtoCopyWithImpl;
@override @useResult
$Res call({
 bool? supportsReasoningEffort, List<GrokReasoningEffortOptionDto> reasoningEfforts, String? reasoningEffort
});




}
/// @nodoc
class __$GrokModelMetadataDtoCopyWithImpl<$Res>
    implements _$GrokModelMetadataDtoCopyWith<$Res> {
  __$GrokModelMetadataDtoCopyWithImpl(this._self, this._then);

  final _GrokModelMetadataDto _self;
  final $Res Function(_GrokModelMetadataDto) _then;

/// Create a copy of GrokModelMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supportsReasoningEffort = freezed,Object? reasoningEfforts = null,Object? reasoningEffort = freezed,}) {
  return _then(_GrokModelMetadataDto(
supportsReasoningEffort: freezed == supportsReasoningEffort ? _self.supportsReasoningEffort : supportsReasoningEffort // ignore: cast_nullable_to_non_nullable
as bool?,reasoningEfforts: null == reasoningEfforts ? _self._reasoningEfforts : reasoningEfforts // ignore: cast_nullable_to_non_nullable
as List<GrokReasoningEffortOptionDto>,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GrokModelInfoDto {

 String? get modelId; String? get name; String? get description;@JsonKey(name: "_meta") GrokModelMetadataDto? get metadata;
/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokModelInfoDtoCopyWith<GrokModelInfoDto> get copyWith => _$GrokModelInfoDtoCopyWithImpl<GrokModelInfoDto>(this as GrokModelInfoDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokModelInfoDto&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,name,description,metadata);

@override
String toString() {
  return 'GrokModelInfoDto(modelId: $modelId, name: $name, description: $description, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $GrokModelInfoDtoCopyWith<$Res>  {
  factory $GrokModelInfoDtoCopyWith(GrokModelInfoDto value, $Res Function(GrokModelInfoDto) _then) = _$GrokModelInfoDtoCopyWithImpl;
@useResult
$Res call({
 String? modelId, String? name, String? description,@JsonKey(name: "_meta") GrokModelMetadataDto? metadata
});


$GrokModelMetadataDtoCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$GrokModelInfoDtoCopyWithImpl<$Res>
    implements $GrokModelInfoDtoCopyWith<$Res> {
  _$GrokModelInfoDtoCopyWithImpl(this._self, this._then);

  final GrokModelInfoDto _self;
  final $Res Function(GrokModelInfoDto) _then;

/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? modelId = freezed,Object? name = freezed,Object? description = freezed,Object? metadata = freezed,}) {
  return _then(GrokModelInfoDto(
modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GrokModelMetadataDto?,
  ));
}
/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokModelMetadataDtoCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GrokModelMetadataDtoCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokModelInfoDto implements GrokModelInfoDto {
  const _GrokModelInfoDto({required this.modelId, required this.name, required this.description, @JsonKey(name: "_meta") required this.metadata});
  factory _GrokModelInfoDto.fromJson(Map<String, dynamic> json) => _$GrokModelInfoDtoFromJson(json);

@override final  String? modelId;
@override final  String? name;
@override final  String? description;
@override@JsonKey(name: "_meta") final  GrokModelMetadataDto? metadata;

/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokModelInfoDtoCopyWith<_GrokModelInfoDto> get copyWith => __$GrokModelInfoDtoCopyWithImpl<_GrokModelInfoDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokModelInfoDto&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelId,name,description,metadata);

@override
String toString() {
  return 'GrokModelInfoDto(modelId: $modelId, name: $name, description: $description, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$GrokModelInfoDtoCopyWith<$Res> implements $GrokModelInfoDtoCopyWith<$Res> {
  factory _$GrokModelInfoDtoCopyWith(_GrokModelInfoDto value, $Res Function(_GrokModelInfoDto) _then) = __$GrokModelInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 String? modelId, String? name, String? description,@JsonKey(name: "_meta") GrokModelMetadataDto? metadata
});


@override $GrokModelMetadataDtoCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$GrokModelInfoDtoCopyWithImpl<$Res>
    implements _$GrokModelInfoDtoCopyWith<$Res> {
  __$GrokModelInfoDtoCopyWithImpl(this._self, this._then);

  final _GrokModelInfoDto _self;
  final $Res Function(_GrokModelInfoDto) _then;

/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? modelId = freezed,Object? name = freezed,Object? description = freezed,Object? metadata = freezed,}) {
  return _then(_GrokModelInfoDto(
modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GrokModelMetadataDto?,
  ));
}

/// Create a copy of GrokModelInfoDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokModelMetadataDtoCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GrokModelMetadataDtoCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// @nodoc
mixin _$GrokSessionModelStateDto {

 List<GrokModelInfoDto> get availableModels; String? get currentModelId;
/// Create a copy of GrokSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSessionModelStateDtoCopyWith<GrokSessionModelStateDto> get copyWith => _$GrokSessionModelStateDtoCopyWithImpl<GrokSessionModelStateDto>(this as GrokSessionModelStateDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionModelStateDto&&const DeepCollectionEquality().equals(other.availableModels, availableModels)&&(identical(other.currentModelId, currentModelId) || other.currentModelId == currentModelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availableModels),currentModelId);

@override
String toString() {
  return 'GrokSessionModelStateDto(availableModels: $availableModels, currentModelId: $currentModelId)';
}


}

/// @nodoc
abstract mixin class $GrokSessionModelStateDtoCopyWith<$Res>  {
  factory $GrokSessionModelStateDtoCopyWith(GrokSessionModelStateDto value, $Res Function(GrokSessionModelStateDto) _then) = _$GrokSessionModelStateDtoCopyWithImpl;
@useResult
$Res call({
 List<GrokModelInfoDto> availableModels, String? currentModelId
});




}
/// @nodoc
class _$GrokSessionModelStateDtoCopyWithImpl<$Res>
    implements $GrokSessionModelStateDtoCopyWith<$Res> {
  _$GrokSessionModelStateDtoCopyWithImpl(this._self, this._then);

  final GrokSessionModelStateDto _self;
  final $Res Function(GrokSessionModelStateDto) _then;

/// Create a copy of GrokSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availableModels = null,Object? currentModelId = freezed,}) {
  return _then(GrokSessionModelStateDto(
availableModels: null == availableModels ? _self.availableModels : availableModels // ignore: cast_nullable_to_non_nullable
as List<GrokModelInfoDto>,currentModelId: freezed == currentModelId ? _self.currentModelId : currentModelId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokSessionModelStateDto implements GrokSessionModelStateDto {
  const _GrokSessionModelStateDto({ List<GrokModelInfoDto> availableModels = const <GrokModelInfoDto>[], required this.currentModelId}): _availableModels = availableModels;
  factory _GrokSessionModelStateDto.fromJson(Map<String, dynamic> json) => _$GrokSessionModelStateDtoFromJson(json);

 final  List<GrokModelInfoDto> _availableModels;
@override@JsonKey() List<GrokModelInfoDto> get availableModels {
  if (_availableModels is EqualUnmodifiableListView) return _availableModels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableModels);
}

@override final  String? currentModelId;

/// Create a copy of GrokSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokSessionModelStateDtoCopyWith<_GrokSessionModelStateDto> get copyWith => __$GrokSessionModelStateDtoCopyWithImpl<_GrokSessionModelStateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokSessionModelStateDto&&const DeepCollectionEquality().equals(other._availableModels, _availableModels)&&(identical(other.currentModelId, currentModelId) || other.currentModelId == currentModelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availableModels),currentModelId);

@override
String toString() {
  return 'GrokSessionModelStateDto(availableModels: $availableModels, currentModelId: $currentModelId)';
}


}

/// @nodoc
abstract mixin class _$GrokSessionModelStateDtoCopyWith<$Res> implements $GrokSessionModelStateDtoCopyWith<$Res> {
  factory _$GrokSessionModelStateDtoCopyWith(_GrokSessionModelStateDto value, $Res Function(_GrokSessionModelStateDto) _then) = __$GrokSessionModelStateDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GrokModelInfoDto> availableModels, String? currentModelId
});




}
/// @nodoc
class __$GrokSessionModelStateDtoCopyWithImpl<$Res>
    implements _$GrokSessionModelStateDtoCopyWith<$Res> {
  __$GrokSessionModelStateDtoCopyWithImpl(this._self, this._then);

  final _GrokSessionModelStateDto _self;
  final $Res Function(_GrokSessionModelStateDto) _then;

/// Create a copy of GrokSessionModelStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availableModels = null,Object? currentModelId = freezed,}) {
  return _then(_GrokSessionModelStateDto(
availableModels: null == availableModels ? _self._availableModels : availableModels // ignore: cast_nullable_to_non_nullable
as List<GrokModelInfoDto>,currentModelId: freezed == currentModelId ? _self.currentModelId : currentModelId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GrokInitializeMetadataDto {

 bool? get grokShell; String? get agentVersion; GrokSessionModelStateDto? get modelState;
/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokInitializeMetadataDtoCopyWith<GrokInitializeMetadataDto> get copyWith => _$GrokInitializeMetadataDtoCopyWithImpl<GrokInitializeMetadataDto>(this as GrokInitializeMetadataDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokInitializeMetadataDto&&(identical(other.grokShell, grokShell) || other.grokShell == grokShell)&&(identical(other.agentVersion, agentVersion) || other.agentVersion == agentVersion)&&(identical(other.modelState, modelState) || other.modelState == modelState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grokShell,agentVersion,modelState);

@override
String toString() {
  return 'GrokInitializeMetadataDto(grokShell: $grokShell, agentVersion: $agentVersion, modelState: $modelState)';
}


}

/// @nodoc
abstract mixin class $GrokInitializeMetadataDtoCopyWith<$Res>  {
  factory $GrokInitializeMetadataDtoCopyWith(GrokInitializeMetadataDto value, $Res Function(GrokInitializeMetadataDto) _then) = _$GrokInitializeMetadataDtoCopyWithImpl;
@useResult
$Res call({
 bool? grokShell, String? agentVersion, GrokSessionModelStateDto? modelState
});


$GrokSessionModelStateDtoCopyWith<$Res>? get modelState;

}
/// @nodoc
class _$GrokInitializeMetadataDtoCopyWithImpl<$Res>
    implements $GrokInitializeMetadataDtoCopyWith<$Res> {
  _$GrokInitializeMetadataDtoCopyWithImpl(this._self, this._then);

  final GrokInitializeMetadataDto _self;
  final $Res Function(GrokInitializeMetadataDto) _then;

/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? grokShell = freezed,Object? agentVersion = freezed,Object? modelState = freezed,}) {
  return _then(GrokInitializeMetadataDto(
grokShell: freezed == grokShell ? _self.grokShell : grokShell // ignore: cast_nullable_to_non_nullable
as bool?,agentVersion: freezed == agentVersion ? _self.agentVersion : agentVersion // ignore: cast_nullable_to_non_nullable
as String?,modelState: freezed == modelState ? _self.modelState : modelState // ignore: cast_nullable_to_non_nullable
as GrokSessionModelStateDto?,
  ));
}
/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionModelStateDtoCopyWith<$Res>? get modelState {
    if (_self.modelState == null) {
    return null;
  }

  return $GrokSessionModelStateDtoCopyWith<$Res>(_self.modelState!, (value) {
    return _then(_self.copyWith(modelState: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokInitializeMetadataDto implements GrokInitializeMetadataDto {
  const _GrokInitializeMetadataDto({required this.grokShell, required this.agentVersion, required this.modelState});
  factory _GrokInitializeMetadataDto.fromJson(Map<String, dynamic> json) => _$GrokInitializeMetadataDtoFromJson(json);

@override final  bool? grokShell;
@override final  String? agentVersion;
@override final  GrokSessionModelStateDto? modelState;

/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokInitializeMetadataDtoCopyWith<_GrokInitializeMetadataDto> get copyWith => __$GrokInitializeMetadataDtoCopyWithImpl<_GrokInitializeMetadataDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokInitializeMetadataDto&&(identical(other.grokShell, grokShell) || other.grokShell == grokShell)&&(identical(other.agentVersion, agentVersion) || other.agentVersion == agentVersion)&&(identical(other.modelState, modelState) || other.modelState == modelState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grokShell,agentVersion,modelState);

@override
String toString() {
  return 'GrokInitializeMetadataDto(grokShell: $grokShell, agentVersion: $agentVersion, modelState: $modelState)';
}


}

/// @nodoc
abstract mixin class _$GrokInitializeMetadataDtoCopyWith<$Res> implements $GrokInitializeMetadataDtoCopyWith<$Res> {
  factory _$GrokInitializeMetadataDtoCopyWith(_GrokInitializeMetadataDto value, $Res Function(_GrokInitializeMetadataDto) _then) = __$GrokInitializeMetadataDtoCopyWithImpl;
@override @useResult
$Res call({
 bool? grokShell, String? agentVersion, GrokSessionModelStateDto? modelState
});


@override $GrokSessionModelStateDtoCopyWith<$Res>? get modelState;

}
/// @nodoc
class __$GrokInitializeMetadataDtoCopyWithImpl<$Res>
    implements _$GrokInitializeMetadataDtoCopyWith<$Res> {
  __$GrokInitializeMetadataDtoCopyWithImpl(this._self, this._then);

  final _GrokInitializeMetadataDto _self;
  final $Res Function(_GrokInitializeMetadataDto) _then;

/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? grokShell = freezed,Object? agentVersion = freezed,Object? modelState = freezed,}) {
  return _then(_GrokInitializeMetadataDto(
grokShell: freezed == grokShell ? _self.grokShell : grokShell // ignore: cast_nullable_to_non_nullable
as bool?,agentVersion: freezed == agentVersion ? _self.agentVersion : agentVersion // ignore: cast_nullable_to_non_nullable
as String?,modelState: freezed == modelState ? _self.modelState : modelState // ignore: cast_nullable_to_non_nullable
as GrokSessionModelStateDto?,
  ));
}

/// Create a copy of GrokInitializeMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionModelStateDtoCopyWith<$Res>? get modelState {
    if (_self.modelState == null) {
    return null;
  }

  return $GrokSessionModelStateDtoCopyWith<$Res>(_self.modelState!, (value) {
    return _then(_self.copyWith(modelState: value));
  });
}
}


/// @nodoc
mixin _$GrokModelStateEnvelopeDto {

@JsonKey(name: "_meta") GrokInitializeMetadataDto? get metadata; GrokSessionModelStateDto? get models;
/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokModelStateEnvelopeDtoCopyWith<GrokModelStateEnvelopeDto> get copyWith => _$GrokModelStateEnvelopeDtoCopyWithImpl<GrokModelStateEnvelopeDto>(this as GrokModelStateEnvelopeDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokModelStateEnvelopeDto&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.models, models) || other.models == models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metadata,models);

@override
String toString() {
  return 'GrokModelStateEnvelopeDto(metadata: $metadata, models: $models)';
}


}

/// @nodoc
abstract mixin class $GrokModelStateEnvelopeDtoCopyWith<$Res>  {
  factory $GrokModelStateEnvelopeDtoCopyWith(GrokModelStateEnvelopeDto value, $Res Function(GrokModelStateEnvelopeDto) _then) = _$GrokModelStateEnvelopeDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "_meta") GrokInitializeMetadataDto? metadata, GrokSessionModelStateDto? models
});


$GrokInitializeMetadataDtoCopyWith<$Res>? get metadata;$GrokSessionModelStateDtoCopyWith<$Res>? get models;

}
/// @nodoc
class _$GrokModelStateEnvelopeDtoCopyWithImpl<$Res>
    implements $GrokModelStateEnvelopeDtoCopyWith<$Res> {
  _$GrokModelStateEnvelopeDtoCopyWithImpl(this._self, this._then);

  final GrokModelStateEnvelopeDto _self;
  final $Res Function(GrokModelStateEnvelopeDto) _then;

/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metadata = freezed,Object? models = freezed,}) {
  return _then(GrokModelStateEnvelopeDto(
metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GrokInitializeMetadataDto?,models: freezed == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as GrokSessionModelStateDto?,
  ));
}
/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokInitializeMetadataDtoCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GrokInitializeMetadataDtoCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionModelStateDtoCopyWith<$Res>? get models {
    if (_self.models == null) {
    return null;
  }

  return $GrokSessionModelStateDtoCopyWith<$Res>(_self.models!, (value) {
    return _then(_self.copyWith(models: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokModelStateEnvelopeDto implements GrokModelStateEnvelopeDto {
  const _GrokModelStateEnvelopeDto({@JsonKey(name: "_meta") required this.metadata, required this.models});
  factory _GrokModelStateEnvelopeDto.fromJson(Map<String, dynamic> json) => _$GrokModelStateEnvelopeDtoFromJson(json);

@override@JsonKey(name: "_meta") final  GrokInitializeMetadataDto? metadata;
@override final  GrokSessionModelStateDto? models;

/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokModelStateEnvelopeDtoCopyWith<_GrokModelStateEnvelopeDto> get copyWith => __$GrokModelStateEnvelopeDtoCopyWithImpl<_GrokModelStateEnvelopeDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokModelStateEnvelopeDto&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.models, models) || other.models == models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metadata,models);

@override
String toString() {
  return 'GrokModelStateEnvelopeDto(metadata: $metadata, models: $models)';
}


}

/// @nodoc
abstract mixin class _$GrokModelStateEnvelopeDtoCopyWith<$Res> implements $GrokModelStateEnvelopeDtoCopyWith<$Res> {
  factory _$GrokModelStateEnvelopeDtoCopyWith(_GrokModelStateEnvelopeDto value, $Res Function(_GrokModelStateEnvelopeDto) _then) = __$GrokModelStateEnvelopeDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "_meta") GrokInitializeMetadataDto? metadata, GrokSessionModelStateDto? models
});


@override $GrokInitializeMetadataDtoCopyWith<$Res>? get metadata;@override $GrokSessionModelStateDtoCopyWith<$Res>? get models;

}
/// @nodoc
class __$GrokModelStateEnvelopeDtoCopyWithImpl<$Res>
    implements _$GrokModelStateEnvelopeDtoCopyWith<$Res> {
  __$GrokModelStateEnvelopeDtoCopyWithImpl(this._self, this._then);

  final _GrokModelStateEnvelopeDto _self;
  final $Res Function(_GrokModelStateEnvelopeDto) _then;

/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metadata = freezed,Object? models = freezed,}) {
  return _then(_GrokModelStateEnvelopeDto(
metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as GrokInitializeMetadataDto?,models: freezed == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as GrokSessionModelStateDto?,
  ));
}

/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokInitializeMetadataDtoCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $GrokInitializeMetadataDtoCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of GrokModelStateEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionModelStateDtoCopyWith<$Res>? get models {
    if (_self.models == null) {
    return null;
  }

  return $GrokSessionModelStateDtoCopyWith<$Res>(_self.models!, (value) {
    return _then(_self.copyWith(models: value));
  });
}
}

// dart format on
