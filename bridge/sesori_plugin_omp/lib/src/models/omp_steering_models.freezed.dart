// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'omp_steering_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OmpInitializeMetaDto {

@JsonKey(name: "_meta") OmpInitializeExtensionsDto? get meta;
/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpInitializeMetaDtoCopyWith<OmpInitializeMetaDto> get copyWith => _$OmpInitializeMetaDtoCopyWithImpl<OmpInitializeMetaDto>(this as OmpInitializeMetaDto, _$identity);

  /// Serializes this OmpInitializeMetaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OmpInitializeMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpInitializeMetaDto&&(identical(other.meta, _this.meta) || other.meta == _this.meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpInitializeMetaDto;
  return Object.hash(runtimeType,_this.meta);
}

@override
String toString() {
  final _this = this as OmpInitializeMetaDto;
  return 'OmpInitializeMetaDto(meta: ${_this.meta})';
}


}

/// @nodoc
abstract mixin class $OmpInitializeMetaDtoCopyWith<$Res>  {
  factory $OmpInitializeMetaDtoCopyWith(OmpInitializeMetaDto value, $Res Function(OmpInitializeMetaDto) _then) = _$OmpInitializeMetaDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "_meta") OmpInitializeExtensionsDto? meta
});


$OmpInitializeExtensionsDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class _$OmpInitializeMetaDtoCopyWithImpl<$Res>
    implements $OmpInitializeMetaDtoCopyWith<$Res> {
  _$OmpInitializeMetaDtoCopyWithImpl(this._self, this._then);

  final OmpInitializeMetaDto _self;
  final $Res Function(OmpInitializeMetaDto) _then;

/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? meta = freezed,}) {
  return _then(OmpInitializeMetaDto(
meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as OmpInitializeExtensionsDto?,
  ));
}
/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OmpInitializeExtensionsDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $OmpInitializeExtensionsDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _OmpInitializeMetaDto implements OmpInitializeMetaDto {
  const _OmpInitializeMetaDto({@JsonKey(name: "_meta") required this.meta});
  factory _OmpInitializeMetaDto.fromJson(Map<String, dynamic> json) => _$OmpInitializeMetaDtoFromJson(json);

@override@JsonKey(name: "_meta") final  OmpInitializeExtensionsDto? meta;

/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpInitializeMetaDtoCopyWith<_OmpInitializeMetaDto> get copyWith => __$OmpInitializeMetaDtoCopyWithImpl<_OmpInitializeMetaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OmpInitializeMetaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpInitializeMetaDto&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,meta);
}

@override
String toString() {
    return 'OmpInitializeMetaDto(meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$OmpInitializeMetaDtoCopyWith<$Res> implements $OmpInitializeMetaDtoCopyWith<$Res> {
  factory _$OmpInitializeMetaDtoCopyWith(_OmpInitializeMetaDto value, $Res Function(_OmpInitializeMetaDto) _then) = __$OmpInitializeMetaDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "_meta") OmpInitializeExtensionsDto? meta
});


@override $OmpInitializeExtensionsDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class __$OmpInitializeMetaDtoCopyWithImpl<$Res>
    implements _$OmpInitializeMetaDtoCopyWith<$Res> {
  __$OmpInitializeMetaDtoCopyWithImpl(this._self, this._then);

  final _OmpInitializeMetaDto _self;
  final $Res Function(_OmpInitializeMetaDto) _then;

/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = freezed,}) {
  return _then(_OmpInitializeMetaDto(
meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as OmpInitializeExtensionsDto?,
  ));
}

/// Create a copy of OmpInitializeMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OmpInitializeExtensionsDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $OmpInitializeExtensionsDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc
mixin _$OmpInitializeExtensionsDto {

 OmpSteeringCapabilityDto? get steering;
/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpInitializeExtensionsDtoCopyWith<OmpInitializeExtensionsDto> get copyWith => _$OmpInitializeExtensionsDtoCopyWithImpl<OmpInitializeExtensionsDto>(this as OmpInitializeExtensionsDto, _$identity);

  /// Serializes this OmpInitializeExtensionsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OmpInitializeExtensionsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpInitializeExtensionsDto&&(identical(other.steering, _this.steering) || other.steering == _this.steering));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpInitializeExtensionsDto;
  return Object.hash(runtimeType,_this.steering);
}

@override
String toString() {
  final _this = this as OmpInitializeExtensionsDto;
  return 'OmpInitializeExtensionsDto(steering: ${_this.steering})';
}


}

/// @nodoc
abstract mixin class $OmpInitializeExtensionsDtoCopyWith<$Res>  {
  factory $OmpInitializeExtensionsDtoCopyWith(OmpInitializeExtensionsDto value, $Res Function(OmpInitializeExtensionsDto) _then) = _$OmpInitializeExtensionsDtoCopyWithImpl;
@useResult
$Res call({
 OmpSteeringCapabilityDto? steering
});


$OmpSteeringCapabilityDtoCopyWith<$Res>? get steering;

}
/// @nodoc
class _$OmpInitializeExtensionsDtoCopyWithImpl<$Res>
    implements $OmpInitializeExtensionsDtoCopyWith<$Res> {
  _$OmpInitializeExtensionsDtoCopyWithImpl(this._self, this._then);

  final OmpInitializeExtensionsDto _self;
  final $Res Function(OmpInitializeExtensionsDto) _then;

/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? steering = freezed,}) {
  return _then(OmpInitializeExtensionsDto(
steering: freezed == steering ? _self.steering : steering // ignore: cast_nullable_to_non_nullable
as OmpSteeringCapabilityDto?,
  ));
}
/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OmpSteeringCapabilityDtoCopyWith<$Res>? get steering {
    if (_self.steering == null) {
    return null;
  }

  return $OmpSteeringCapabilityDtoCopyWith<$Res>(_self.steering!, (value) {
    return _then(_self.copyWith(steering: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _OmpInitializeExtensionsDto implements OmpInitializeExtensionsDto {
  const _OmpInitializeExtensionsDto({required this.steering});
  factory _OmpInitializeExtensionsDto.fromJson(Map<String, dynamic> json) => _$OmpInitializeExtensionsDtoFromJson(json);

@override final  OmpSteeringCapabilityDto? steering;

/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpInitializeExtensionsDtoCopyWith<_OmpInitializeExtensionsDto> get copyWith => __$OmpInitializeExtensionsDtoCopyWithImpl<_OmpInitializeExtensionsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OmpInitializeExtensionsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpInitializeExtensionsDto&&(identical(other.steering, steering) || other.steering == steering));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,steering);
}

@override
String toString() {
    return 'OmpInitializeExtensionsDto(steering: $steering)';
}


}

/// @nodoc
abstract mixin class _$OmpInitializeExtensionsDtoCopyWith<$Res> implements $OmpInitializeExtensionsDtoCopyWith<$Res> {
  factory _$OmpInitializeExtensionsDtoCopyWith(_OmpInitializeExtensionsDto value, $Res Function(_OmpInitializeExtensionsDto) _then) = __$OmpInitializeExtensionsDtoCopyWithImpl;
@override @useResult
$Res call({
 OmpSteeringCapabilityDto? steering
});


@override $OmpSteeringCapabilityDtoCopyWith<$Res>? get steering;

}
/// @nodoc
class __$OmpInitializeExtensionsDtoCopyWithImpl<$Res>
    implements _$OmpInitializeExtensionsDtoCopyWith<$Res> {
  __$OmpInitializeExtensionsDtoCopyWithImpl(this._self, this._then);

  final _OmpInitializeExtensionsDto _self;
  final $Res Function(_OmpInitializeExtensionsDto) _then;

/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? steering = freezed,}) {
  return _then(_OmpInitializeExtensionsDto(
steering: freezed == steering ? _self.steering : steering // ignore: cast_nullable_to_non_nullable
as OmpSteeringCapabilityDto?,
  ));
}

/// Create a copy of OmpInitializeExtensionsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OmpSteeringCapabilityDtoCopyWith<$Res>? get steering {
    if (_self.steering == null) {
    return null;
  }

  return $OmpSteeringCapabilityDtoCopyWith<$Res>(_self.steering!, (value) {
    return _then(_self.copyWith(steering: value));
  });
}
}


/// @nodoc
mixin _$OmpSteeringCapabilityDto {

 bool? get supported;
/// Create a copy of OmpSteeringCapabilityDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpSteeringCapabilityDtoCopyWith<OmpSteeringCapabilityDto> get copyWith => _$OmpSteeringCapabilityDtoCopyWithImpl<OmpSteeringCapabilityDto>(this as OmpSteeringCapabilityDto, _$identity);

  /// Serializes this OmpSteeringCapabilityDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OmpSteeringCapabilityDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpSteeringCapabilityDto&&(identical(other.supported, _this.supported) || other.supported == _this.supported));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpSteeringCapabilityDto;
  return Object.hash(runtimeType,_this.supported);
}

@override
String toString() {
  final _this = this as OmpSteeringCapabilityDto;
  return 'OmpSteeringCapabilityDto(supported: ${_this.supported})';
}


}

/// @nodoc
abstract mixin class $OmpSteeringCapabilityDtoCopyWith<$Res>  {
  factory $OmpSteeringCapabilityDtoCopyWith(OmpSteeringCapabilityDto value, $Res Function(OmpSteeringCapabilityDto) _then) = _$OmpSteeringCapabilityDtoCopyWithImpl;
@useResult
$Res call({
 bool? supported
});




}
/// @nodoc
class _$OmpSteeringCapabilityDtoCopyWithImpl<$Res>
    implements $OmpSteeringCapabilityDtoCopyWith<$Res> {
  _$OmpSteeringCapabilityDtoCopyWithImpl(this._self, this._then);

  final OmpSteeringCapabilityDto _self;
  final $Res Function(OmpSteeringCapabilityDto) _then;

/// Create a copy of OmpSteeringCapabilityDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supported = freezed,}) {
  return _then(OmpSteeringCapabilityDto(
supported: freezed == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _OmpSteeringCapabilityDto implements OmpSteeringCapabilityDto {
  const _OmpSteeringCapabilityDto({required this.supported});
  factory _OmpSteeringCapabilityDto.fromJson(Map<String, dynamic> json) => _$OmpSteeringCapabilityDtoFromJson(json);

@override final  bool? supported;

/// Create a copy of OmpSteeringCapabilityDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpSteeringCapabilityDtoCopyWith<_OmpSteeringCapabilityDto> get copyWith => __$OmpSteeringCapabilityDtoCopyWithImpl<_OmpSteeringCapabilityDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OmpSteeringCapabilityDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpSteeringCapabilityDto&&(identical(other.supported, supported) || other.supported == supported));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,supported);
}

@override
String toString() {
    return 'OmpSteeringCapabilityDto(supported: $supported)';
}


}

/// @nodoc
abstract mixin class _$OmpSteeringCapabilityDtoCopyWith<$Res> implements $OmpSteeringCapabilityDtoCopyWith<$Res> {
  factory _$OmpSteeringCapabilityDtoCopyWith(_OmpSteeringCapabilityDto value, $Res Function(_OmpSteeringCapabilityDto) _then) = __$OmpSteeringCapabilityDtoCopyWithImpl;
@override @useResult
$Res call({
 bool? supported
});




}
/// @nodoc
class __$OmpSteeringCapabilityDtoCopyWithImpl<$Res>
    implements _$OmpSteeringCapabilityDtoCopyWith<$Res> {
  __$OmpSteeringCapabilityDtoCopyWithImpl(this._self, this._then);

  final _OmpSteeringCapabilityDto _self;
  final $Res Function(_OmpSteeringCapabilityDto) _then;

/// Create a copy of OmpSteeringCapabilityDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supported = freezed,}) {
  return _then(_OmpSteeringCapabilityDto(
supported: freezed == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
mixin _$OmpSteeringParams {

 String get sessionId;/// ACP content blocks, the same shape as `session/prompt`'s `prompt`.
 List<Map<String, dynamic>> get prompt;

  /// Serializes this OmpSteeringParams to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable(createFactory: false)

class _OmpSteeringParams implements OmpSteeringParams {
  const _OmpSteeringParams({required this.sessionId, required  List<Map<String, dynamic>> prompt}): _prompt = prompt;
  

@override final  String sessionId;
/// ACP content blocks, the same shape as `session/prompt`'s `prompt`.
 final  List<Map<String, dynamic>> _prompt;
/// ACP content blocks, the same shape as `session/prompt`'s `prompt`.
@override List<Map<String, dynamic>> get prompt {
  if (_prompt is EqualUnmodifiableListView) return _prompt;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_prompt);
}



@override
Map<String, dynamic> toJson() {
  return _$OmpSteeringParamsToJson(this, );
}





}





/// @nodoc
mixin _$OmpSteeringResultDto {

@JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) OmpSteeringOutcome get outcome; String? get reason;
/// Create a copy of OmpSteeringResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpSteeringResultDtoCopyWith<OmpSteeringResultDto> get copyWith => _$OmpSteeringResultDtoCopyWithImpl<OmpSteeringResultDto>(this as OmpSteeringResultDto, _$identity);

  /// Serializes this OmpSteeringResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OmpSteeringResultDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpSteeringResultDto&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.reason, _this.reason) || other.reason == _this.reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpSteeringResultDto;
  return Object.hash(runtimeType,_this.outcome,_this.reason);
}

@override
String toString() {
  final _this = this as OmpSteeringResultDto;
  return 'OmpSteeringResultDto(outcome: ${_this.outcome}, reason: ${_this.reason})';
}


}

/// @nodoc
abstract mixin class $OmpSteeringResultDtoCopyWith<$Res>  {
  factory $OmpSteeringResultDtoCopyWith(OmpSteeringResultDto value, $Res Function(OmpSteeringResultDto) _then) = _$OmpSteeringResultDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) OmpSteeringOutcome outcome, String? reason
});




}
/// @nodoc
class _$OmpSteeringResultDtoCopyWithImpl<$Res>
    implements $OmpSteeringResultDtoCopyWith<$Res> {
  _$OmpSteeringResultDtoCopyWithImpl(this._self, this._then);

  final OmpSteeringResultDto _self;
  final $Res Function(OmpSteeringResultDto) _then;

/// Create a copy of OmpSteeringResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? reason = freezed,}) {
  return _then(OmpSteeringResultDto(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OmpSteeringOutcome,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _OmpSteeringResultDto implements OmpSteeringResultDto {
  const _OmpSteeringResultDto({@JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) required this.outcome, required this.reason});
  factory _OmpSteeringResultDto.fromJson(Map<String, dynamic> json) => _$OmpSteeringResultDtoFromJson(json);

@override@JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) final  OmpSteeringOutcome outcome;
@override final  String? reason;

/// Create a copy of OmpSteeringResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpSteeringResultDtoCopyWith<_OmpSteeringResultDto> get copyWith => __$OmpSteeringResultDtoCopyWithImpl<_OmpSteeringResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OmpSteeringResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpSteeringResultDto&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,outcome,reason);
}

@override
String toString() {
    return 'OmpSteeringResultDto(outcome: $outcome, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$OmpSteeringResultDtoCopyWith<$Res> implements $OmpSteeringResultDtoCopyWith<$Res> {
  factory _$OmpSteeringResultDtoCopyWith(_OmpSteeringResultDto value, $Res Function(_OmpSteeringResultDto) _then) = __$OmpSteeringResultDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: OmpSteeringOutcome.unknown) OmpSteeringOutcome outcome, String? reason
});




}
/// @nodoc
class __$OmpSteeringResultDtoCopyWithImpl<$Res>
    implements _$OmpSteeringResultDtoCopyWith<$Res> {
  __$OmpSteeringResultDtoCopyWithImpl(this._self, this._then);

  final _OmpSteeringResultDto _self;
  final $Res Function(_OmpSteeringResultDto) _then;

/// Create a copy of OmpSteeringResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? reason = freezed,}) {
  return _then(_OmpSteeringResultDto(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OmpSteeringOutcome,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
